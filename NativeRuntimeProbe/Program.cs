using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;

namespace HugoNativeProbe
{
    // Read-only snapshot of /proc. Does not run system commands, inject
    // code, load any VPN libraries, or change networking / firmware.
    class Program : NUIApplication
    {
        private TextLabel _label;

        private static string ReadStatus(string path)
        {
            try { return File.ReadAllText(path); }
            catch { return null; }
        }

        private static string Field(string status, string key)
        {
            if (String.IsNullOrEmpty(status)) return "indisponivel";
            foreach (var line in status.Split('\n'))
            {
                if (line.StartsWith(key, StringComparison.Ordinal))
                    return line.Substring(key.Length).Trim();
            }
            return "nao visivel";
        }

        private static int? Uid(string status)
        {
            var text = Field(status, "Uid:");
            var parts = text.Split(new [] {' ', '\t'}, StringSplitOptions.RemoveEmptyEntries);
            int uid;
            return parts.Length > 0 && Int32.TryParse(parts[0], out uid) ? (int?)uid : null;
        }

        private static string NetAdmin(string capHex)
        {
            ulong value;
            if (!UInt64.TryParse(capHex, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out value))
                return "desconhecida";
            return (value & (1UL << 12)) != 0 ? "PRESENTE" : "AUSENTE";
        }

        private static string Snapshot()
        {
            var sb = new StringBuilder();
            sb.AppendLine("HUGO - SDK PROCESS CHECK v0.5");
            sb.AppendLine("Q60A / Tizen 6.0 - APENAS CONSULTA");
            sb.AppendLine("");
            var mine = ReadStatus("/proc/self/status");
            var ownHex = Field(mine, "CapEff:");
            sb.AppendLine("Processo desta app: UID " + Field(mine,"Uid:"));
            sb.AppendLine("CapEff app: " + ownHex);
            sb.AppendLine("CAP_NET_ADMIN app: " + NetAdmin(ownHex));
            sb.AppendLine("");
            sb.AppendLine("A procurar processos UID 901 (sdk)...");

            int scanned = 0, inaccessible = 0, matches = 0;
            string failure = null;
            var results = new List<string>();
            try
            {
                foreach (var dir in Directory.EnumerateDirectories("/proc"))
                {
                    int pid;
                    var name = System.IO.Path.GetFileName(dir);
                    if (!Int32.TryParse(name, out pid)) continue;
                    scanned++;
                    var status = ReadStatus("/proc/" + name + "/status");
                    if (status == null)
                    {
                        inaccessible++;
                        continue;
                    }

                    if (Uid(status) != 901) continue;
                    matches++;
                    if (results.Count < 6)
                    {
                        var cap = Field(status,"CapEff:");
                        var process = Field(status,"Name:");
                        // Mask PID and names that might identify apps;
                        // retain only effective-capabilities diagnosis.
                        results.Add("sdk #" + matches + " -> CapEff " + cap +
                                    ", CAP_NET_ADMIN " + NetAdmin(cap));
                    }
                }
            }
            catch (Exception e)
            {
                failure = e.GetType().Name;
            }

            sb.AppendLine("Processos numericos visiveis: " + scanned);
            sb.AppendLine("Estados inacessiveis: " + inaccessible);
            sb.AppendLine("Processos UID 901 encontrados: " + matches);
            if (failure != null) sb.AppendLine("Enumeracao limitada: " + failure);
            foreach (var line in results) sb.AppendLine(line);

            sb.AppendLine("");
            if (matches == 0)
            {
                sb.AppendLine("RESULTADO INCONCLUSIVO.");
                sb.AppendLine("O comando sdk anterior foi temporario.");
                sb.AppendLine("Nao encontrar um processo ativo NAO");
                sb.AppendLine("prova ausencia de CAP_NET_ADMIN em sdk.");
            }
            else
            {
                sb.AppendLine("Amostra de processos observados apenas.");
                sb.AppendLine("Uma capacidade num processo nao garante");
                sb.AppendLine("a mesma capacidade noutro contexto.");
            }
            sb.AppendLine("");
            sb.AppendLine("OK: repetir leitura | Voltar: sair.");
            sb.AppendLine("Sem root, SDB exploit, init VPN ou rotas.");
            return sb.ToString();
        }

        protected override void OnCreate()
        {
            base.OnCreate();
            Window.Instance.BackgroundColor = new Color(0.08f, 0.10f, 0.16f, 1.0f);
            _label = new TextLabel(Snapshot())
            {
                TextColor = new Color(1.0f, 1.0f, 1.0f, 1.0f),
                PointSize = 19.0f,
                MultiLine = true,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                WidthResizePolicy = ResizePolicyType.FillToParent,
                HeightResizePolicy = ResizePolicyType.FillToParent
            };
            Window.Instance.GetDefaultLayer().Add(_label);
            Window.Instance.KeyEvent += OnKeyEvent;
        }

        private void OnKeyEvent(object sender, Window.KeyEventArgs e)
        {
            if (e.Key.State != Key.StateType.Down) return;
            string key = e.Key.KeyPressedName;
            if (key == "XF86Back" || key == "Escape")
            {
                Exit();
                return;
            }
            if (key == "Return" || key == "KP_Enter" || key == "Select")
                _label.Text = Snapshot();
        }

        static void Main(string[] args)
        {
            new Program().Run(args);
        }
    }
}
