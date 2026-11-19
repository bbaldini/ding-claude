# Badge sull'icona della barra delle applicazioni di Windows (ITaskbarList3::SetOverlayIcon).
#
#   badge.ps1 -Mode capture            stampa l'HWND della finestra in primo piano
#   badge.ps1 -Mode show -Hwnd <n>     mette il badge (cloche/campanella) su quella finestra,
#                                      resta in attesa e lo toglie quando torni sulla finestra
#   badge.ps1 -Mode demo [-Hwnd <n>]   mostra il badge per 8 secondi (prova)
param(
  [ValidateSet('capture', 'show', 'demo')][string]$Mode = 'capture',
  [long]$Hwnd = 0,
  [int]$MaxHours = 12
)

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

[ComImport, Guid("ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ITaskbarList3 {
  [PreserveSig] int HrInit();
  [PreserveSig] int AddTab(IntPtr h);
  [PreserveSig] int DeleteTab(IntPtr h);
  [PreserveSig] int ActivateTab(IntPtr h);
  [PreserveSig] int SetActiveAlt(IntPtr h);
  [PreserveSig] int MarkFullscreenWindow(IntPtr h, bool f);
  [PreserveSig] int SetProgressValue(IntPtr h, ulong done, ulong total);
  [PreserveSig] int SetProgressState(IntPtr h, int flags);
  [PreserveSig] int RegisterTab(IntPtr tab, IntPtr main);
  [PreserveSig] int UnregisterTab(IntPtr tab);
  [PreserveSig] int SetTabOrder(IntPtr tab, IntPtr before);
  [PreserveSig] int SetTabActive(IntPtr tab, IntPtr main, uint reserved);
  [PreserveSig] int ThumbBarAddButtons(IntPtr h, uint n, IntPtr buttons);
  [PreserveSig] int ThumbBarUpdateButtons(IntPtr h, uint n, IntPtr buttons);
  [PreserveSig] int ThumbBarSetImageList(IntPtr h, IntPtr list);
  [PreserveSig] int SetOverlayIcon(IntPtr h, IntPtr icon, [MarshalAs(UnmanagedType.LPWStr)] string desc);
}

[ComImport, Guid("56fdf344-fd6d-11d0-958a-006097c9a090")]
class TaskbarListCoClass {}

public static class DingBadge {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);

  static ITaskbarList3 bar;
  static IntPtr icon = IntPtr.Zero;

  public static long Foreground() {
    IntPtr h = GetForegroundWindow();
    IntPtr root = GetAncestor(h, 3); // GA_ROOTOWNER
    return (long)(root != IntPtr.Zero ? root : h);
  }

  // Cloche (coperchio da piatto / campanello da reception) bianca su un cerchio arancione saturo bordato di nero.
  static IntPtr Draw() {
    using (var bmp = new Bitmap(32, 32))
    using (var g = Graphics.FromImage(bmp)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.Clear(Color.Transparent);
      using (var bg = new SolidBrush(Color.FromArgb(255, 255, 90, 20)))
        g.FillEllipse(bg, 1, 1, 29, 29);
      using (var k = new Pen(Color.Black, 2))
        g.DrawEllipse(k, 1, 1, 29, 29);         // bordo nero
      using (var w = new SolidBrush(Color.White)) {
        g.FillEllipse(w, 14, 5, 4, 4);          // pomello
        g.FillPie(w, 7, 8, 18, 24, 180, 180);   // cupola
        g.FillRectangle(w, 5, 21, 22, 3);       // piatto
      }
      return bmp.GetHicon();
    }
  }

  public static void Show(long hwnd) {
    bar = (ITaskbarList3)new TaskbarListCoClass();
    bar.HrInit();
    icon = Draw();
    bar.SetOverlayIcon((IntPtr)hwnd, icon, "Claude ha finito");
  }

  public static void Clear(long hwnd) {
    if (bar != null) bar.SetOverlayIcon((IntPtr)hwnd, IntPtr.Zero, null);
    if (icon != IntPtr.Zero) { DestroyIcon(icon); icon = IntPtr.Zero; }
  }
}
'@

if ($Mode -eq 'capture') {
  [DingBadge]::Foreground()
  exit 0
}

if ($Mode -eq 'demo') {
  if ($Hwnd -eq 0) { $Hwnd = [DingBadge]::Foreground() }
  [DingBadge]::Show($Hwnd)
  Start-Sleep -Seconds 8
  [DingBadge]::Clear($Hwnd)
  exit 0
}

if ($Hwnd -eq 0 -or -not [DingBadge]::IsWindow([IntPtr]$Hwnd)) { exit 0 }
# Se stai già guardando la finestra non serve il badge.
if ([DingBadge]::Foreground() -eq $Hwnd) { exit 0 }

[DingBadge]::Show($Hwnd)
$deadline = (Get-Date).AddHours($MaxHours)
try {
  while ((Get-Date) -lt $deadline -and [DingBadge]::IsWindow([IntPtr]$Hwnd)) {
    if ([DingBadge]::Foreground() -eq $Hwnd) { break }
    Start-Sleep -Milliseconds 500
  }
} finally {
  [DingBadge]::Clear($Hwnd)
}
