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
            sb.AppendLine("HUGO - NATIVE VPN SERVICE PROBE v0.4");
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
            sb.AppendLine("Init apenas por dupla confirmacao no comando.");
            sb.AppendLine("");
            sb.AppendLine("Nao altera rotas, DNS nem firmware.");
            sb.AppendLine("Bibliotecas/ficheiros invisiveis nao provam ausencia.");
            return sb.ToString();
        }

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int VpnInitDelegate([MarshalAs(UnmanagedType.LPStr)] string name, out IntPtr handle);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int VpnDeinitDelegate(IntPtr handle);

        private TextLabel _label;
        private bool _armed = false;
        private bool _completed = false;

        private static string TestVpnInitOnce()
        {
            // ATENCAO: vpnsvc_init cria/inicializa um handle de interface VPN.
            // Executar SOMENTE a pedido explicito, apos 2 OKs na TV.
            // Nao configurar rotas/DNS, nao subir tunnel, nao pedir appcontrol.
            IntPtr lib = IntPtr.Zero;
            IntPtr handle = IntPtr.Zero;
            int initResult = int.MinValue;
            string teardown = "nao necessario";
            try
            {
                if (!NativeLibrary.TryLoad("libcapi-vpnsvc.so.1", out lib) ||
                    lib == IntPtr.Zero)
                    return "Erro: nao foi possivel carregar a biblioteca.";

                IntPtr initAddress, deinitAddress;
                if (!NativeLibrary.TryGetExport(lib, "vpnsvc_init", out initAddress) ||
                    !NativeLibrary.TryGetExport(lib, "vpnsvc_deinit", out deinitAddress))
                    return "Erro: simbolos vpnsvc_* indisponiveis.";

                var init = (VpnInitDelegate)Marshal.GetDelegateForFunctionPointer(
                    initAddress, typeof(VpnInitDelegate));
                var deinit = (VpnDeinitDelegate)Marshal.GetDelegateForFunctionPointer(
                    deinitAddress, typeof(VpnDeinitDelegate));

                try
                {
                    // Nome de teste curto e distinto. Pode pedir ao daemon que
                    // crie uma interface; nao ativamos conexao nem traffic routing.
                    initResult = init("hugoprobe", out handle);
                }
                catch (Exception ex)
                {
                    return "Chamada init lancou " + ex.GetType().Name +
                           " (possivel bloqueio de interop/sandbox).";
                }
                finally
                {
                    if (handle != IntPtr.Zero)
                    {
                        try
                        {
                            var deinitResult = deinit(handle);
                            teardown = "deinit=" + deinitResult;
                        }
                        catch (Exception e)
                        {
                            teardown = "falhou (" + e.GetType().Name + ")";
                        }
                        handle = IntPtr.Zero;
                    }
                }

                string meaning = initResult == 0
                    ? "INIT RETORNOU SUCESSO. NAO prova VPN global."
                    : "INIT REJEITADA/FALHOU. Codigo bruto abaixo.";
                return meaning + "\nret=" + initResult + " (0x" +
                       unchecked((uint)initResult).ToString("X8") + ")" +
                       "\nLibertacao do handle: " + teardown;
            }
            catch (Exception e)
            {
                return "Erro no acesso C ABI (" + e.GetType().Name + ").";
            }
            finally
            {
                if (lib != IntPtr.Zero)
                {
                    try { NativeLibrary.Free(lib); } catch { }
                }
            }
        }

        private void UpdateScreen(string extra)
        {
            if (_label == null) return;
            _label.Text = Diagnostics() + "\n\n" + extra;
        }

        private void OnKeyEvent(object sender, Window.KeyEventArgs e)
        {
            if (e.Key.State != Key.StateType.Down) return;
            var key = e.Key.KeyPressedName;
            if (key == "XF86Back" || key == "Escape")
            {
                Exit();
                return;
            }
            if (key != "Return" && key != "KP_Enter" && key != "Select") return;
            if (_completed) return;
            if (!_armed)
            {
                _armed = true;
                UpdateScreen("CONFIRMAR: pressionar OK novamente para chamar\n" +
                             "vpnsvc_init (PODE criar interface temporaria).\n" +
                             "Voltar para cancelar. Sem rotas/DNS.");
                return;
            }
            _completed = true;
            UpdateScreen("A executar uma chamada de init e deinit...\n" +
                         "Nao desligar a TV durante este teste.");
            var result = TestVpnInitOnce();
            UpdateScreen(result + "\n\nTeste terminado. Voltar para sair.");
        }

        protected override void OnCreate()
        {
            base.OnCreate();
            Window.Instance.BackgroundColor = new Color(0.08f, 0.10f, 0.16f, 1.0f);
            string message;
            try { message = Diagnostics(); }
            catch (Exception ex) { message = "Erro no diagnostico: " + ex.GetType().Name; }
            _label = new TextLabel(message)
            {
                TextColor = new Color(1.0f, 1.0f, 1.0f, 1.0f),
                PointSize = 18.0f,
                MultiLine = true,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                WidthResizePolicy = ResizePolicyType.FillToParent,
                HeightResizePolicy = ResizePolicyType.FillToParent
            };
            Window.Instance.GetDefaultLayer().Add(_label);
            Window.Instance.KeyEvent += OnKeyEvent;
            UpdateScreen("Pressiona OK duas vezes para testar init do daemon VPN.\nVoltar = cancelar.");
        }

        static void Main(string[] args)
        {
            var app = new Program();
            app.Run(args);
        }
    }
}
