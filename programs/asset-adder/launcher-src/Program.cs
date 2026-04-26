using System.Diagnostics;

var repoRoot = Directory.GetParent(AppContext.BaseDirectory)!.Parent!.Parent!.Parent!.FullName;
var scriptPath = Path.Combine(repoRoot, "programs", "asset-adder", "launch-asset-adder.ps1");

if (!File.Exists(scriptPath))
{
    Console.Error.WriteLine($"Missing script: {scriptPath}");
    return 1;
}

var psi = new ProcessStartInfo
{
    FileName = "powershell.exe",
    Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"",
    UseShellExecute = false
};

using var process = Process.Start(psi);
if (process is null)
{
    Console.Error.WriteLine("Failed to start PowerShell process.");
    return 1;
}

process.WaitForExit();
return process.ExitCode;

