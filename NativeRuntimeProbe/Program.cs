using System;
using System.IO;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;

namespace HugoNativeProbe
{
    // Diagnostico estritamente de leitura: nao chama APIs nativas de VPN,
    // nao abre o dispositivo TUN, nao executa comandos e nao muda rotas.
    class Program : NUIApplication
    {
        private static string ReadFile(string path)
        {
            try { return File.ReadAllText(path); }
            catch (Exception e) { return "INDISPONIVEL (" + e.GetType().Name + ")"; }
        }

        private static string StatusValue(string status, string key)
        {
            if (status.StartsWith("INDISPONIVEL")) return "desconhecido";
            foreach (var rawLine in status.Split('\n'))
            {
                var line = rawLine.Trim();
                if (line.StartsWith(key, StringComparison.Ordinal))
                    return line.Substring(key.Length).Trim();
            }
            return "nao visivel";
        }

        private static string KernelInterfaces()
        {
            try
            {
                var items = new List<string>();
                foreach (var line in File.ReadAllLines("/proc/net/dev"))
                {
                    int colon = line.IndexOf(':');
                    if (colon < 0) continue;
                    var name = line.Substring(0, colon).Trim();
                    if (name != "lo" && name.Length > 0) items.Add(name);
                    if (items.Count >= 8) break;
                }
                return items.Count == 0 ? "nenhuma visivel" : string.Join(", ", items);
            }
            catch (Exception e) { return "indisponivel (" + e.GetType().Name + ")"; }
        }

        private static string VpnLibraries()
        {
            // Apenas lista nomes de arquivos e devolve resposta cautelosa.
            var dirs = new [] { "/usr/lib", "/usr/lib32", "/lib", "/usr/lib/arm-linux-gnueabihf" };
            var results = new List<string>();
            bool scanned = false;
            foreach (var dir in dirs)
            {
                try
                {
                    if (!Directory.Exists(dir)) continue;
                    scanned = true;
                    foreach (var entry in Directory.EnumerateFiles(dir, "*vpn*"))
                    {
                        var name = System.IO.Path.GetFileName(entry);
                        if (!results.Contains(name)) results.Add(name);
                        if (results.Count >= 5) break;
                    }
                    if (results.Count >= 5) break;
                }
                catch { }
            }
            if (results.Count > 0) return string.Join(", ", results);
            return scanned ? "nenhuma encontrada nestas pastas" : "bibliotecas inacessiveis";
        }

        private static string VpnLoaderProbe()
        {
            // Somente resolve carregamento e simbolos: NAO invoca vpnsvc_init
            // ou qualquer outra funcao VPN. Uma tentativa de carregamento
            // pode ser negada pelo sandbox da Samsung TV.
            IntPtr handle = IntPtr.Zero;
            try
            {
                if (!NativeLibrary.TryLoad("libcapi-vpnsvc.so.1", out handle) ||
                    handle == IntPtr.Zero)
                    return "LOAD NEGADO/FALHOU (motivo nao determinado)";

                IntPtr init = IntPtr.Zero;
                IntPtr deinit = IntPtr.Zero;
                bool hasInit = NativeLibrary.TryGetExport(handle, "vpnsvc_init", out init);
                bool hasDeinit = NativeLibrary.TryGetExport(handle, "vpnsvc_deinit", out deinit);
                return "LOAD OK; init=" + (hasInit ? "SIM" : "NAO") +
                       ", deinit=" + (hasDeinit ? "SIM" : "NAO");
            }
            catch (Exception e)
            {
                return "ERRO (" + e.GetType().Name + ")";
            }
            finally
            {
                if (handle != IntPtr.Zero)
                {
                    try { NativeLibrary.Free(handle); }
                    catch { }
                }
            }
        }

        private static string CapNetAdmin(string status)
        {
            var hex = StatusValue(status, "CapEff:");
            ulong caps;
            if (!ulong.TryParse(hex, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out caps))
                return "desconhecido (" + hex + ")";
            // Linux capability CAP_NET_ADMIN = bit 12.
            return (caps & (1UL << 12)) != 0 ? "PRESENTE" : "AUSENTE";
        }

        private static string Diagnostics()
        {
            var status = ReadFile("/proc/self/status");
            var tunVisible = File.Exists("/dev/net/tun");
            var kernel = ReadFile("/proc/sys/kernel/osrelease").Trim();
            if (kernel.Length > 65) kernel = kernel.Substring(0, 65);

            var sb = new StringBuilder();
            sb.AppendLine("HUGO - NATIVE VPN LOADER PROBE v0.3");
            sb.AppendLine("Samsung Q60A / Tizen 6.0 - leitura apenas");
            sb.AppendLine("");
            sb.AppendLine(".NET / TPK: EXECUCAO CONFIRMADA");
            sb.AppendLine("Kernel: " + kernel);
            sb.AppendLine("UID(s) do processo: " + StatusValue(status, "Uid:"));
            sb.AppendLine("CapEff (hex): " + StatusValue(status, "CapEff:"));
            sb.AppendLine("CAP_NET_ADMIN: " + CapNetAdmin(status));
            sb.AppendLine("NoNewPrivs: " + StatusValue(status, "NoNewPrivs:"));
            sb.AppendLine("/dev/net/tun: " + (tunVisible ? "VISIVEL" : "NAO VISIVEL"));
            sb.AppendLine("Interfaces de rede: " + KernelInterfaces());
            sb.AppendLine("Bibliotecas *vpn*: " + VpnLibraries());
            sb.AppendLine("Carregamento vpnsvc: " + VpnLoaderProbe());
            sb.AppendLine("Nao invoca vpnsvc_init nem altera rotas.");
            sb.AppendLine("");
            sb.AppendLine("Nao cria VPN nem altera rotas/firmware.");
            sb.AppendLine("Bibliotecas/ficheiros invisiveis nao provam ausencia.");
            return sb.ToString();
        }

        protected override void OnCreate()
        {
            base.OnCreate();
            Window.Instance.BackgroundColor = new Color(0.08f, 0.10f, 0.16f, 1.0f);
            string message;
            try { message = Diagnostics(); }
            catch (Exception ex) { message = "Erro no diagnostico: " + ex.GetType().Name; }
            var label = new TextLabel(message)
            {
                TextColor = new Color(1.0f, 1.0f, 1.0f, 1.0f),
                PointSize = 20.0f,
                MultiLine = true,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                WidthResizePolicy = ResizePolicyType.FillToParent,
                HeightResizePolicy = ResizePolicyType.FillToParent
            };
            Window.Instance.GetDefaultLayer().Add(label);
        }

        static void Main(string[] args)
        {
            var app = new Program();
            app.Run(args);
        }
    }
}
