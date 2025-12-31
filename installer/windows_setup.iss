; ==================== 琥珀清单 Windows 安装包脚本 ====================
; 使用 Inno Setup 6.x 编译
;
; 功能：
; - 打包 Flutter build 产物（含所有 DLL）
; - 创建开始菜单快捷方式
; - 创建桌面快捷方式（可选）
; - 支持卸载
; ==================================================================

#define MyAppName "琥珀清单"
#define MyAppNameEn "AmberList"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Amber List Team"
#define MyAppURL "https://github.com/user/amber-list"
#define MyAppExeName "amber_list.exe"

[Setup]
; 应用基本信息
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 安装目录
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 输出设置
OutputDir=..\build\installer
OutputBaseFilename=AmberList_Setup_{#MyAppVersion}
; SetupIconFile=..\assets\icons\app_icon.ico  ; TODO: 添加自定义图标后取消注释
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; 权限设置（不需要管理员权限）
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; UI 设置
WizardStyle=modern
DisableWelcomePage=no
ShowLanguageDialog=auto

; 架构
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
; 只用英文，GitHub Actions 的 Inno Setup 没有中文语言包
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 复制整个 Release 目录（包含 exe、dll、data 文件夹等）
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 开始菜单快捷方式
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
; 桌面快捷方式（用户选择）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后运行（可选）
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时清理用户数据目录（可选，谨慎使用）
; Type: filesandordirs; Name: "{userappdata}\amber-list"
