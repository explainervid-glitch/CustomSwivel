;NSIS Modern User Interface
;Welcome/Finish Page Example Script
;Written by Joost Verburg

;--------------------------------
;Include Modern UI

  !include "MUI2.nsh"

;--------------------------------
;General

  ;Name and file
  Name "Swivel 2"
  OutFile "swivel2-win32.exe"

  ;Default installation folder
  InstallDir "$PROGRAMFILES\Swivel2"

  ;Get installation folder from registry if available
  InstallDirRegKey HKCU "Software\Swivel2" ""

  ;Request application privileges for Windows Vista
  RequestExecutionLevel admin

  SetCompressor /SOLID /FINAL lzma

;--------------------------------
;Variables

  Var StartMenuFolder

Function createDestkopIcon
  CreateShortcut "$DESKTOP\Swivel 2.lnk" "$INSTDIR\Swivel2.exe"
FunctionEnd

;--------------------------------
;Interface Settings

  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_BITMAP "assets\WinInstallerHeader.bmp"
  !define MUI_ABORTWARNING

;--------------------------------
;Pages

  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_LICENSE "LICENSE.md"
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MUI_PAGE_DIRECTORY
  !define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKCU"
  !define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Swivel2"
  !define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
  !insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
  !insertmacro MUI_PAGE_INSTFILES
  !define MUI_FINISHPAGE_RUN "$INSTDIR\Swivel2.exe"
  !define MUI_FINISHPAGE_SHOWREADME ""
  !define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
  !define MUI_FINISHPAGE_SHOWREADME_TEXT "Create Desktop Shortcut"
  !define MUI_FINISHPAGE_SHOWREADME_FUNCTION createDestkopIcon
  !insertmacro MUI_PAGE_FINISH

  !insertmacro MUI_UNPAGE_WELCOME
  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES
  !insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section "Swivel 2" SecSwivel

  SetOutPath "$INSTDIR"

  File /r bin\Swivel\*

  ;Store installation folder
  WriteRegStr HKCU "Software\Swivel2" "" $INSTDIR

  ;Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  SetShellVarContext all
  ;Create shortcuts
  CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
  CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Swivel 2.lnk" "$INSTDIR\Swivel2.exe"
  CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
				
  !insertmacro MUI_STARTMENU_WRITE_END

  ;Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "DisplayName" "Swivel 2"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "DisplayIcon" "$\"$INSTDIR\Swivel2.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "Publisher" "Newgrounds.com, Inc."
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "HelpLink" "http://www.newgrounds.com"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "DisplayVersion" "1.11"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "VersionMajor" "1"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "VersionMinor" "11"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "NoModify" "1"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "NoRepair" "1"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "EstimatedSize" "61440"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2" \
                 "Comments" "SWF to video convertor"
SectionEnd

;--------------------------------
;Descriptions

  ;Language strings
  LangString DESC_SecSwivel ${LANG_ENGLISH} "Swivel 2"

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecSwivel} $(DESC_SecSwivel)
  !insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section

Section "Uninstall"

  ;ADD YOUR OWN FILES HERE...

  Delete "$INSTDIR\Uninstall.exe"

  RMDir /r "$INSTDIR"

  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  SetShellVarContext all
  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\Swivel 2.lnk"
  RMDir /r "$SMPROGRAMS\$StartMenuFolder"

  DeleteRegKey /ifempty HKCU "Software\Swivel2"
  DeleteRegKey  HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2"

SectionEnd