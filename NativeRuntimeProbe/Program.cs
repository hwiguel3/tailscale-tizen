using System;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;

namespace HugoNativeProbe
{
    class Program : NUIApplication
    {
        protected override void OnCreate()
        {
            base.OnCreate();
            Window.Instance.BackgroundColor = new Color(0.08f, 0.10f, 0.16f, 1.0f);

            var label = new TextLabel("Hugo · Native Tizen 6.0\n\nTeste mínimo .NET / TPK executado!\n\nNão altera VPN nem firmware.")
            {
                TextColor = new Color(1.0f, 1.0f, 1.0f, 1.0f),
                PointSize = 28.0f,
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
