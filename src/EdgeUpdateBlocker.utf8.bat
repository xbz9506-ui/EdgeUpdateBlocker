@echo off
rem ============================================================================
rem  Edge Update Blocker  -  Microsoft Edge 自动更新禁用工具
rem  单文件批处理 / 无依赖 / 每一项都可还原
rem  设计参照：Windows Update Blocker (Sordum) 的 Protect Service Settings 机制
rem
rem  用法:
rem    EdgeUpdateBlocker.bat             交互菜单（默认）
rem    EdgeUpdateBlocker.bat --auto      直接执行最强组合
rem    EdgeUpdateBlocker.bat --status    只读体检
rem    EdgeUpdateBlocker.bat --dryrun    空跑演练
rem    EdgeUpdateBlocker.bat --guard     静默加固（计划任务调用）
rem    EdgeUpdateBlocker.bat --pick 3    直接进入第 3 项（自动 dryrun）
rem ============================================================================

chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

set "APP_NAME=Edge Update Blocker"
set "APP_VER=1.1.0"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOGDIR=%ROOT%\logs"
set "BAKDIR=%ROOT%\backup"
set "LOGF=%LOGDIR%\EdgeUpdateBlocker.log"
set "PFLAG=%LOGDIR%\.protect.on"

rem ---- 关键路径 --------------------------------------------------------------
set "PF86=%ProgramFiles(x86)%"
if not defined PF86 set "PF86=%ProgramFiles%"
set "EU_X86=%PF86%\Microsoft\EdgeUpdate"
set "EU_ALT=%PF86%\Microsoft\disableEdgeUpdate"
set "EU_X64=%ProgramFiles%\Microsoft\EdgeUpdate"
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"

rem ---- hosts 标记 ------------------------------------------------------------
set "HK1=# ===== EdgeUpdateBlocker BEGIN ====="
set "HK2=# ===== EdgeUpdateBlocker END ====="

rem ---- 防火墙规则名 ----------------------------------------------------------
set "FW1=EdgeUpdateBlocker-x86"
set "FW2=EdgeUpdateBlocker-x64"

rem ---- Edge 各通道 GUID ------------------------------------------------------
set "G_STABLE={56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"
set "G_BETA={2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}"
set "G_DEV={0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}"
set "G_CANARY={65C35B14-6C1D-4122-AC46-7148CC9D6497}"
set "G_WEBVIEW2={F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

rem ---- 受保护的更新服务 ------------------------------------------------------
set "SVCLIST=edgeupdate edgeupdatem MicrosoftEdgeElevationService"

set "WV2=0"
set "MODE=menu"

rem ---- 权限检测（全局只算一次，各模式共用） --------------------------------
call :IS_ADMIN
if errorlevel 1 (
    set "ISADMIN=0"
) else (
    set "ISADMIN=1"
)

rem ============================================================================
rem  参数分派
rem ============================================================================
if /i "%~1"=="--status" goto :RUN_STATUS
if /i "%~1"=="--guard"  goto :RUN_GUARD
if /i "%~1"=="-h"       goto :SHOW_HELP
if /i "%~1"=="--help"   goto :SHOW_HELP
if /i "%~1"=="/?"       goto :SHOW_HELP
if /i "%~1"=="--dryrun" (set "DRYRUN=1" & goto :MENU)
if /i "%~1"=="--pick"   (set "DRYRUN=1" & set "AUTOPICK=1" & set "PICK=%~2" & goto :MENU)
if /i "%~1"=="--auto"   set "MODE=auto"
if /i "%~1"=="--upgrade" set "MODE=upgrade"

rem ---- 除只读入口外，一律强制管理员 ----------------------------------------
if "%ISADMIN%"=="0" (
    call :ELEVATE "%~1"
    exit /b 1
)
title Edge Update Blocker v%APP_VER%  [管理员]

if /i "%MODE%"=="auto" goto :RUN_AUTO
if /i "%MODE%"=="upgrade" goto :RUN_UPGRADE
goto :MENU


rem ============================================================================
rem  管理员判定（三重检测，避免单一命令误判）
rem ============================================================================
:IS_ADMIN
net session >nul 2>&1
if not errorlevel 1 exit /b 0
fltmc >nul 2>&1
if not errorlevel 1 exit /b 0
whoami /groups 2>nul | findstr /c:"S-1-16-12288" >nul 2>&1
if not errorlevel 1 exit /b 0
exit /b 1


rem ============================================================================
rem  自提权
rem ============================================================================
:ELEVATE
cls
echo.
echo  ==================================================================
echo    需要管理员权限才能修改系统设置
echo  ==================================================================
echo.
echo    正在请求 UAC 提权，请在弹窗中点击「是」...
echo    点「否」则本程序不会对系统做任何修改。
echo.
set "EARG="
if /i "%~1"=="--auto"    set "EARG=--auto"
if /i "%~1"=="--upgrade" set "EARG=--upgrade"
if defined EARG (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%EARG%' -Verb RunAs" >nul 2>&1
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
)
if errorlevel 1 goto :ELEVATE_FAIL
echo.
echo    已发起提权请求，本窗口即将关闭。
timeout /t 3 >nul 2>&1
exit /b 0

:ELEVATE_FAIL
echo.
echo    [X] 提权未成功：可能点了「否」，或系统禁用了 PowerShell。
echo.
echo    请手动操作：
echo      1. 关闭本窗口
echo      2. 右键 EdgeUpdateBlocker.bat
echo      3. 选择「以管理员身份运行」
echo.
pause
exit /b 1


rem ============================================================================
rem  基础工具
rem ============================================================================
:LOG
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
>>"%LOGF%" echo [%date% %time%] %~1
exit /b 0

:BANNER
cls
echo.
echo  ==================================================================
echo         Edge Update Blocker   v%APP_VER%
echo         Microsoft Edge 自动更新禁用工具  ^|  单文件  ^|  需管理员
echo  ==================================================================
exit /b 0

:LINE
echo  ------------------------------------------------------------------
exit /b 0

:PAUSEIT
echo.
echo   按任意键返回主菜单...
pause >nul
exit /b 0

:ASK
rem  %1=提示  %2=默认(Y/N)   errorlevel 0=Y 1=N
set "ANS=%~2"
set /p "ANS=  %~1 [%~2]: "
if /i "!ANS!"=="Y" exit /b 0
if /i "!ANS!"=="N" exit /b 1
exit /b 1


rem ============================================================================
rem  WUB 风格状态面板
rem ============================================================================
:PANEL
if defined DRYRUN (
    set "P_SVC=?"
    set "P_PROT=?"
    set "P_POL=?"
    set "P_HST=?"
    set "P_FW=?"
    set "P_ACL=?"
    set "P_REN=?"
    set "P_TSK=?"
    exit /b 0
)

rem 服务启动类型
set "P_SVC=未禁用"
sc qc edgeupdate >nul 2>&1
if errorlevel 1 (
    set "P_SVC=无此服务"
) else (
    for /f "tokens=4" %%A in ('sc qc edgeupdate 2^>nul ^| findstr /i "START_TYPE"') do (
        if /i "%%A"=="DISABLED" (set "P_SVC=已禁用") else (set "P_SVC=%%A")
    )
)

rem 服务保护（标记文件，体检里会实测）
set "P_PROT=关"
if exist "%PFLAG%" set "P_PROT=开"

rem 组策略
set "P_POL=未写入"
reg query "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v UpdateDefault >nul 2>&1
if not errorlevel 1 set "P_POL=已写入"

rem hosts
set "P_HST=未屏蔽"
if exist "%HOSTS%" findstr /c:"EdgeUpdateBlocker BEGIN" "%HOSTS%" >nul 2>&1
if not errorlevel 1 set "P_HST=已屏蔽"

rem 防火墙
set "P_FW=无规则"
netsh advfirewall firewall show rule name="%FW1%" >nul 2>&1
if not errorlevel 1 set "P_FW=已拦截"

rem 目录 ACL
set "P_ACL=目录缺失"
if exist "%EU_X86%" (
    set "P_ACL=可写"
    >"%EU_X86%\.eultest.tmp" echo x 2>nul
    if exist "%EU_X86%\.eultest.tmp" (
        del "%EU_X86%\.eultest.tmp" >nul 2>&1
    ) else (
        set "P_ACL=已锁死"
    )
)

rem 更新器文件
set "P_REN=未找到"
for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do if exist "%%~D\MicrosoftEdgeUpdate.exe" set "P_REN=原版"
if "%P_REN%"=="未找到" for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do if exist "%%~D\MicrosoftEdgeUpdate.exe.bak" set "P_REN=已改名"

rem 计划任务
set "P_TSK=已清除"
set "TL0=%TEMP%\eul_p_%RANDOM%.txt"
schtasks /query /fo csv /nh > "%TL0%" 2>nul
if exist "%TL0%" for /f "usebackq delims=" %%A in (`findstr /i /c:"MicrosoftEdgeUpdateTask" "%TL0%" 2^>nul`) do set "P_TSK=仍存在"
if exist "%TL0%" del "%TL0%" >nul 2>&1
exit /b 0

:PANEL_SHOW
echo.
if "%ISADMIN%"=="1" (
    echo   运行权限 : 管理员  ^|  全部功能可用
) else (
    echo   运行权限 : 非管理员  ^|  只能看，不能改
)
echo   ------------------------------------------------------------------
echo   服务状态 : !P_SVC!      更新器文件 : !P_REN!
echo   服务保护 : !P_PROT!      目录锁     : !P_ACL!
echo   策略锁   : !P_POL!      计划任务   : !P_TSK!
echo   hosts    : !P_HST!      防火墙     : !P_FW!
exit /b 0


rem ============================================================================
rem  主菜单
rem ============================================================================
:MENU
call :BANNER
call :PANEL
call :PANEL_SHOW
call :LINE
echo    单项措施（可自由组合，推荐顺序 1 -^> 2 -^> 3 -^> 7 -^> 6 -^> 4 -^> 5）
call :LINE
echo    [1]  禁用更新服务        edgeupdate / edgeupdatem / Elevation
echo    [2]  铲除更新计划任务    MicrosoftEdgeUpdateTask*
echo    [3]  写入组策略禁令      UpdateDefault=0（微软官方开关）
echo    [4]  hosts 屏蔽端点      msedge.api.cdp.microsoft.com
echo    [5]  防火墙出站拦截      MicrosoftEdgeUpdate.exe
echo    [6]  目录 ACL 锁死       EdgeUpdate 目录拒绝写入
echo    [7]  更新器改名          MicrosoftEdgeUpdate.exe -^> .bak
echo    [8]  保护服务设置        WUB 同款：锁死服务注册表，谁改都不行
echo.
call :LINE
echo    [9]  ★ 一键最强组合     1+2+3+7+6+4+5+8
echo    [A]  开机自愈守护       每小时 SYSTEM 静默重跑核心项
echo    [B]  运行状态体检       逐项实测，只读
echo    [C]  备份当前环境       注册表 / hosts / 服务 / ACL
echo    [D]  恢复还原全部       解除所有限制（不升级）
echo    [E]  风险与原理说明
echo    [F]  一键还原升级       解除限制 -^> 还原目录 -^> 拉取最新版 -^> 可回锁
echo.
echo    [0]  退出
echo.
if not "%ISADMIN%"=="1" (
    echo  ==================================================================
    echo    [!!] 非管理员模式：所有修改类操作都不可用
    echo         请关闭本窗口，右键本文件 -^>「以管理员身份运行」
    echo  ==================================================================
    echo.
)
goto :READ_INPUT

:READ_INPUT
if defined PICK (
    set "CH=!PICK!"
    set "PICK="
    goto :DISPATCH
)
set "TRY=0"
:READ_AGAIN
set "CH="
set /p "CH=  请选择: "
if defined CH goto :DISPATCH
set /a TRY+=1
if %TRY% GEQ 3 (
    echo.
    echo   连续 3 次未读到输入，退出。
    exit /b 1
)
goto :READ_AGAIN

:DISPATCH
if "%CH%"=="0" exit /b 0
if /i "%CH%"=="B" goto :D_GO
if /i "%CH%"=="E" goto :D_GO
rem  空跑演练不改系统，放行以便做无权限回归
if defined DRYRUN goto :D_GO
if not "%ISADMIN%"=="1" goto :NEED_ADMIN
:D_GO
if /i "%CH%"=="1" goto :M_SVC
if /i "%CH%"=="2" goto :M_TASK
if /i "%CH%"=="3" goto :M_REG
if /i "%CH%"=="4" goto :M_HOSTS
if /i "%CH%"=="5" goto :M_FW
if /i "%CH%"=="6" goto :M_ACL
if /i "%CH%"=="7" goto :M_REN
if /i "%CH%"=="8" goto :M_PROT
if /i "%CH%"=="9" goto :M_ALL
if /i "%CH%"=="A" goto :M_GUARD
if /i "%CH%"=="B" goto :M_CHECK
if /i "%CH%"=="C" goto :M_BACKUP
if /i "%CH%"=="D" goto :M_RESTORE
if /i "%CH%"=="E" goto :M_DOC
if /i "%CH%"=="F" goto :M_UPGRADE
goto :MENU

:M_SVC
call :UI_SVC
goto :AFTER
:M_TASK
call :UI_TASK
goto :AFTER
:M_REG
call :UI_REG
goto :AFTER
:M_HOSTS
call :UI_HOSTS
goto :AFTER
:M_FW
call :UI_FW
goto :AFTER
:M_ACL
call :UI_ACL
goto :AFTER
:M_REN
call :UI_REN
goto :AFTER
:M_PROT
call :UI_PROT
goto :AFTER
:M_ALL
call :UI_ALL
goto :AFTER
:M_GUARD
call :UI_GUARD
goto :AFTER
:M_CHECK
call :SHOW_STATUS
call :PAUSEIT
goto :AFTER
:M_BACKUP
call :UI_BACKUP
goto :AFTER
:M_RESTORE
call :UI_RESTORE
goto :AFTER
:M_DOC
call :SHOW_DOC
goto :AFTER
:M_UPGRADE
call :UI_UPGRADE
goto :AFTER

:NEED_ADMIN
echo.
echo    [X] 该操作需要管理员权限，已被拦截。
echo        请右键本文件 -^> 「以管理员身份运行」后重试。
echo.
pause
goto :MENU

:AFTER
if defined AUTOPICK exit /b 0
goto :MENU


rem ============================================================================
rem  [1] 服务
rem ============================================================================
:UI_SVC
call :BANNER
echo    [方式 1] 禁用 Edge 更新服务
echo.
call :DO_SVC
call :PAUSEIT
exit /b 0

:DO_SVC
if defined DRYRUN (
    echo    [DRY]  taskkill + sc stop + sc config start= disabled  x3
    exit /b 0
)
taskkill /f /im MicrosoftEdgeUpdate.exe >nul 2>&1
taskkill /f /im MicrosoftEdgeUpdateOnDemand.exe >nul 2>&1
for %%S in (%SVCLIST%) do (
    sc query %%S >nul 2>&1
    if errorlevel 1 (
        echo    [--]   %%S  不存在，跳过
    ) else (
        sc stop %%S >nul 2>&1
        sc config %%S start= disabled >nul 2>&1
        if errorlevel 1 (
            echo    [ERR]  %%S  禁用失败（若已开启服务保护，先执行 [8] 关闭）
            call :LOG "SVC ERR %%S"
        ) else (
            echo    [OK]   %%S  已停止并禁用
            call :LOG "SVC DISABLED %%S"
        )
    )
)
exit /b 0


rem ============================================================================
rem  [2] 计划任务
rem ============================================================================
:UI_TASK
call :BANNER
echo    [方式 2] 铲除 Edge 更新计划任务
echo.
call :DO_TASK
call :PAUSEIT
exit /b 0

:DO_TASK
if defined DRYRUN (
    echo    [DRY]  schtasks disable + delete  MicrosoftEdgeUpdateTask*
    exit /b 0
)
set "TLIST=%TEMP%\eul_task_%RANDOM%.txt"
if exist "%TLIST%" del "%TLIST%" >nul 2>&1
schtasks /query /fo csv /nh > "%TLIST%" 2>nul
set "TCNT=0"
if exist "%TLIST%" (
    for /f "usebackq tokens=1 delims=," %%A in (`findstr /i /c:"MicrosoftEdgeUpdateTask" "%TLIST%" 2^>nul`) do (
        set "TN=%%~A"
        if not "!TN!"=="" (
            echo    [..]   !TN!
            schtasks /change /tn "!TN!" /disable >nul 2>&1
            schtasks /delete /tn "!TN!" /f >nul 2>&1
            if errorlevel 1 (
                echo           删除被拒，已置为禁用
                call :LOG "TASK DISABLED !TN!"
            ) else (
                echo           已删除
                call :LOG "TASK DELETED !TN!"
            )
            set /a TCNT+=1
        )
    )
)
if exist "%TLIST%" del "%TLIST%" >nul 2>&1
if "%TCNT%"=="0" echo    [--]   未发现 Edge 更新计划任务（可能早已移除）
exit /b 0


rem ============================================================================
rem  [3] 组策略
rem ============================================================================
:UI_REG
call :BANNER
echo    [方式 3] 写入 EdgeUpdate 组策略（微软官方开关）
echo.
echo    UpdateDefault=0              禁止应用任何更新
echo    AutoUpdateCheckPeriodMinutes 关闭周期性检查
echo    UpdatesSuppressed*           全天抑制更新窗口
echo    Update{GUID}=0               逐个通道关闭
echo.
set "WV2=0"
call :ASK "同时冻结 WebView2 运行时？（Teams/Office 等可能依赖）" "N"
if not errorlevel 1 set "WV2=1"
echo.
call :DO_REG
echo.
if "%WV2%"=="1" (echo    [OK]   已包含 WebView2 冻结) else (echo    [OK]   WebView2 保持可更新)
echo.
echo    注：该策略在已入域设备上强制生效；家庭版同样会被 EdgeUpdate
echo        读取，但仍需与 1/2/6/7 叠加才彻底。
call :PAUSEIT
exit /b 0

:DO_REG
if defined DRYRUN (
    echo    [DRY]  reg add HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate  + WOW6432Node  x10
    exit /b 0
)
call :REG_KEY "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate"
call :REG_KEY "HKLM\SOFTWARE\WOW6432Node\Policies\Microsoft\EdgeUpdate"
echo    [OK]   组策略已写入 32/64 位两处
call :LOG "REG POLICY WRITTEN WV2=%WV2%"
exit /b 0

:REG_KEY
set "K=%~1"
reg add "%K%" /f >nul 2>&1
reg add "%K%" /v UpdateDefault                /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v UpdatesSuppressedDurationMin /t REG_DWORD /d 1439 /f >nul 2>&1
reg add "%K%" /v UpdatesSuppressedStartHour   /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v UpdatesSuppressedStartMin    /t REG_DWORD /d 1    /f >nul 2>&1
reg add "%K%" /v "Update%G_STABLE%"           /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v "Update%G_BETA%"             /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v "Update%G_DEV%"              /t REG_DWORD /d 0    /f >nul 2>&1
reg add "%K%" /v "Update%G_CANARY%"           /t REG_DWORD /d 0    /f >nul 2>&1
if "%WV2%"=="1" reg add "%K%" /v "Update%G_WEBVIEW2%" /t REG_DWORD /d 0 /f >nul 2>&1
exit /b 0


rem ============================================================================
rem  [4] hosts
rem ============================================================================
:UI_HOSTS
call :BANNER
echo    [方式 4] hosts 屏蔽 Edge 更新端点
echo.
echo    仅拦更新域名，不动 edge.microsoft.com（扩展商店/同步）。
call :DO_HOSTS
call :PAUSEIT
exit /b 0

:DO_HOSTS
if defined DRYRUN (
    echo    [DRY]  append 5 lines to hosts
    exit /b 0
)
if not exist "%HOSTS%" (
    echo    [ERR]  找不到 hosts
    exit /b 0
)
findstr /c:"EdgeUpdateBlocker BEGIN" "%HOSTS%" >nul 2>&1
if not errorlevel 1 (
    echo    [--]   hosts 已存在屏蔽段落，跳过
    exit /b 0
)
if not exist "%BAKDIR%" md "%BAKDIR%" >nul 2>&1
copy /y "%HOSTS%" "%BAKDIR%\hosts.orig.bak" >nul 2>&1
attrib -r -h -s "%HOSTS%" >nul 2>&1
>>"%HOSTS%" echo.
>>"%HOSTS%" echo %HK1%
>>"%HOSTS%" echo 127.0.0.1 msedge.api.cdp.microsoft.com
>>"%HOSTS%" echo 127.0.0.1 msedge.b.tlu.dl.delivery.mp.microsoft.com
>>"%HOSTS%" echo 127.0.0.1 msedge.f.dlu.delivery.mp.microsoft.com
>>"%HOSTS%" echo %HK2%
ipconfig /flushdns >nul 2>&1
echo    [OK]   已写入 3 条屏蔽记录并刷新 DNS
call :LOG "HOSTS BLOCKED"
exit /b 0

:HOSTS_RESTORE
if not exist "%HOSTS%" exit /b 0
findstr /c:"EdgeUpdateBlocker BEGIN" "%HOSTS%" >nul 2>&1
if errorlevel 1 (
    echo    [--]   hosts 无本工具写入的段落
    exit /b 0
)
set "TMPH=%TEMP%\eul_hosts_%RANDOM%.txt"
set "SKIPF="
type nul > "%TMPH%"
for /f "usebackq delims=" %%L in ("%HOSTS%") do (
    if "%%L"=="%HK1%" set "SKIPF=1"
    if not defined SKIPF if not "%%L"=="" >>"%TMPH%" echo %%L
    if "%%L"=="%HK2%" set "SKIPF="
)
copy /y "%TMPH%" "%HOSTS%" >nul 2>&1
del "%TMPH%" >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo    [OK]   hosts 屏蔽段落已清除
call :LOG "HOSTS RESTORED"
exit /b 0


rem ============================================================================
rem  [5] 防火墙
rem ============================================================================
:UI_FW
call :BANNER
echo    [方式 5] 防火墙出站拦截更新器
echo.
call :DO_FW
call :PAUSEIT
exit /b 0

:DO_FW
if defined DRYRUN (
    echo    [DRY]  netsh advfirewall add rule dir=out action=block  x2
    exit /b 0
)
set "FDIR="
if exist "%EU_X86%\MicrosoftEdgeUpdate.exe" set "FDIR=%EU_X86%"
if not defined FDIR if exist "%EU_ALT%\MicrosoftEdgeUpdate.exe" set "FDIR=%EU_ALT%"
if not defined FDIR if exist "%EU_X64%\MicrosoftEdgeUpdate.exe" set "FDIR=%EU_X64%"
if not defined FDIR (
    echo    [--]   未找到更新器可执行文件，无需拦截
    exit /b 0
)
netsh advfirewall firewall delete rule name="%FW1%" >nul 2>&1
netsh advfirewall firewall add rule name="%FW1%" dir=out program="%FDIR%\MicrosoftEdgeUpdate.exe" action=block enable=yes profile=any >nul 2>&1
if errorlevel 1 (
    echo    [ERR]  出站规则创建失败
) else (
    echo    [OK]   已阻断 "%FDIR%\MicrosoftEdgeUpdate.exe"
    call :LOG "FW BLOCK %FDIR%"
)
exit /b 0


rem ============================================================================
rem  [6] 目录 ACL
rem ============================================================================
:UI_ACL
call :BANNER
echo    [方式 6] 目录 ACL 锁死
echo.
echo    对 EdgeUpdate 目录递归拒绝 Everyone 的「写入 / 删除」。
echo    副作用：日后卸载或修复 Edge 会失败，需先用 [D] 还原。
echo.
call :ASK "确认加锁" "Y"
if errorlevel 1 exit /b 0
echo.
call :DO_ACL
call :PAUSEIT
exit /b 0

:DO_ACL
if defined DRYRUN (
    echo    [DRY]  icacls EdgeUpdate /deny Everyone WriteData+AppendData /T
    exit /b 0
)
taskkill /f /im MicrosoftEdgeUpdate.exe >nul 2>&1
call :ACL_ONE "%EU_X86%" 1
call :ACL_ONE "%EU_ALT%" 0
exit /b 0

:ACL_ONE
set "AD=%~1"
set "MKD=%~2"
if exist "%AD%" goto :ACL_APPLY
if not "%MKD%"=="1" (
    echo    [--]   "%AD%"  不存在
    exit /b 0
)
rem  目录不存在时建空占位：服务仍指向该路径，占位后更新器无法落地
md "%AD%" >nul 2>&1
if not exist "%AD%" (
    echo    [--]   "%AD%"  无法创建，跳过
    exit /b 0
)
echo    [..]   已创建空占位目录 "%AD%"
:ACL_APPLY
icacls "%AD%" /deny "*S-1-1-0:(OI)(CI)(WD,AD)" /T /C /Q >nul 2>&1
if errorlevel 1 (
    echo    [ERR]  "%AD%"  加锁失败
    call :LOG "ACL ERR %AD%"
) else (
    echo    [OK]   "%AD%"  已拒绝 Everyone 写入（可还原）
    call :LOG "ACL LOCK %AD%"
)
exit /b 0


rem ============================================================================
rem  [7] 改名
rem ============================================================================
:UI_REN
call :BANNER
echo    [方式 7] 更新器改名
echo.
echo    MicrosoftEdgeUpdate.exe -^> MicrosoftEdgeUpdate.exe.bak
echo    完全可逆，但大版本升级可能补回原文件。
echo.
call :DO_REN
call :PAUSEIT
exit /b 0

:DO_REN
if defined DRYRUN (
    echo    [DRY]  ren MicrosoftEdgeUpdate.exe to .bak  x86 + x64
    exit /b 0
)
rem  自适应探测：标准目录优先，其次是被改过名的 disableEdgeUpdate
set "RDIR="
if exist "%EU_X86%\MicrosoftEdgeUpdate.exe" set "RDIR=%EU_X86%"
if not defined RDIR if exist "%EU_ALT%\MicrosoftEdgeUpdate.exe" set "RDIR=%EU_ALT%"
if not defined RDIR if exist "%EU_X64%\MicrosoftEdgeUpdate.exe" set "RDIR=%EU_X64%"
if not defined RDIR (
    echo    [--]   未找到 MicrosoftEdgeUpdate.exe
    echo          更新器可能已被移除或改名，无需再处理
    exit /b 0
)
taskkill /f /im MicrosoftEdgeUpdate.exe >nul 2>&1
if exist "%RDIR%\MicrosoftEdgeUpdate.exe.bak" del "%RDIR%\MicrosoftEdgeUpdate.exe.bak" >nul 2>&1
ren "%RDIR%\MicrosoftEdgeUpdate.exe" "MicrosoftEdgeUpdate.exe.bak" >nul 2>&1
if errorlevel 1 (
    echo    [ERR]  改名失败："%RDIR%"  ^(目录可能已被 ACL 锁死^)
    call :LOG "RENAME ERR %RDIR%"
) else (
    echo    [OK]   已改名："%RDIR%\MicrosoftEdgeUpdate.exe.bak"
    call :LOG "RENAME OK %RDIR%"
)
exit /b 0


rem ============================================================================
rem  [8] 保护服务设置（WUB 同款）
rem ============================================================================
:UI_PROT
call :BANNER
echo    [方式 8] 保护服务设置   (Protect Service Settings)
echo.
echo    原理：对服务注册表键追加一条 Deny 规则，拒绝 SYSTEM 的
echo          「设置数值」权限。此后 Windows 更新、Edge 自身都无法把
echo          Start 改回 2/3；管理员仍可通过 [D] 正常还原。
echo.
echo    这也是 Windows Update Blocker 唯一「真正防回滚」的那一招。
echo.
if exist "%PFLAG%" (
    echo    当前状态：已开启
    echo.
    call :ASK "是否关闭保护（改为可编辑）" "N"
    if not errorlevel 1 goto :PROT_OFF
    echo.
    echo    [--]   保持保护，未做改动
    call :PAUSEIT
    exit /b 0
) else (
    echo    当前状态：未开启
    echo.
    call :ASK "确认开启保护" "Y"
    if errorlevel 1 exit /b 0
    goto :PROT_ON
)

:PROT_ON
if defined DRYRUN (
    echo    [DRY]  Set-Acl deny Everyone SetValue on edgeupdate / edgeupdatem / Elevation
    exit /b 0
)
echo.
call :DO_PROT_ON
call :PAUSEIT
exit /b 0

:PROT_OFF
if defined DRYRUN (
    echo    [DRY]  remove deny ACE
    exit /b 0
)
echo.
call :DO_PROT_OFF
call :PAUSEIT
exit /b 0

:DO_PROT_ON
if defined DRYRUN (
    echo    [DRY]  Set-Acl deny Everyone SetValue on edgeupdate / edgeupdatem / Elevation
    exit /b 0
)
rem  PS 代码内禁止出现 | ^ 与双引号：变量展开后会被 cmd 当成操作符
set "PS=$sid=New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18');$rt=[System.Security.AccessControl.RegistryRights]::SetValue;$ok=0;$bad=0;foreach($s in @('edgeupdate','edgeupdatem','MicrosoftEdgeElevationService')){$p='HKLM:\SYSTEM\CurrentControlSet\Services\'+$s;if(Test-Path $p){try{$a=Get-Acl $p;$r=New-Object System.Security.AccessControl.RegistryAccessRule($sid,$rt,'Deny');$a.AddAccessRule($r);Set-Acl -Path $p -AclObject $a;$ok++}catch{$bad++}}};Set-Content -Path ($env:TEMP+'\eul_prot_res.txt') -Value $ok -Encoding ascii;Write-Host ('  protected=' + $ok + '  failed=' + $bad);if($ok -eq 0){exit 1}"
set "RESF=%TEMP%\eul_prot_res.txt"
if exist "%RESF%" del "%RESF%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "%PS%" 2>&1
set "POK=0"
if exist "%RESF%" set /p POK=<"%RESF%"
if exist "%RESF%" del "%RESF%" >nul 2>&1
if "%POK%"=="0" (
    echo    [ERR]  保护未生效（PowerShell 不可用、被策略限制或服务不存在）
    call :LOG "PROTECT ERR"
    exit /b 0
)
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
copy /y nul "%PFLAG%" >nul 2>&1
echo    [OK]   已锁定 %POK% 个服务键，Start 值现已被冻结
call :LOG "PROTECT ON keys=%POK%"
exit /b 0

:DO_PROT_OFF
if defined DRYRUN (
    echo    [DRY]  remove deny ACE from service registry keys
    exit /b 0
)
set "PS=$ok=0;foreach($s in @('edgeupdate','edgeupdatem','MicrosoftEdgeElevationService')){$p='HKLM:\SYSTEM\CurrentControlSet\Services\'+$s;if(Test-Path $p){try{$a=Get-Acl $p;$a.Access.Where({$_.AccessControlType -eq 'Deny'}).ForEach({[void]$a.RemoveAccessRule($_)});Set-Acl -Path $p -AclObject $a;$ok++}catch{}}};Set-Content -Path ($env:TEMP+'\eul_prot_off.txt') -Value $ok -Encoding ascii;Write-Host ('  unlocked=' + $ok)"
set "RESF=%TEMP%\eul_prot_off.txt"
if exist "%RESF%" del "%RESF%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "%PS%" 2>&1
set "UOK=0"
if exist "%RESF%" set /p UOK=<"%RESF%"
if exist "%RESF%" del "%RESF%" >nul 2>&1
if exist "%PFLAG%" del "%PFLAG%" >nul 2>&1
echo    [OK]   服务注册表保护已解除（%UOK% 个键）
call :LOG "PROTECT OFF keys=%UOK%"
exit /b 0


rem ============================================================================
rem  [9] 一键最强组合
rem ============================================================================
:UI_ALL
call :BANNER
echo    [9] 一键最强组合
echo.
echo    顺序：服务 -^> 任务 -^> 策略 -^> 改名 -^> ACL -^> 保护 -^> hosts -^> 防火墙
echo    日志：%LOGF%
echo.
call :ASK "确认执行" "Y"
if errorlevel 1 exit /b 0
echo.
call :DO_ALL_LAYERS
echo.
call :LINE
echo    [完成] 八层防护已叠加，建议接着跑 [B] 体检确认。
call :LINE
call :LOG "ALL-IN-ONE DONE"
call :PAUSEIT
exit /b 0

:DO_ALL_LAYERS
call :DO_SVC
echo.
call :DO_TASK
echo.
call :DO_REG
echo.
call :DO_REN
echo.
call :DO_ACL
echo.
call :DO_PROT_ON
echo.
call :DO_HOSTS
echo.
call :DO_FW
exit /b 0


rem ============================================================================
rem  [A] 守护任务
rem ============================================================================
:UI_GUARD
call :BANNER
echo    [A] 开机自愈守护
echo.
echo    把本工具复制到 %ProgramData%\EdgeUpdateBlocker\guard.bat，
echo    再建一个 SYSTEM 计划任务每小时静默重跑「服务+任务+策略」。
echo.
echo    代价：部分杀软会把「SYSTEM + 每小时批处理」判定为可疑。
echo.
call :ASK "确认安装守护任务" "N"
if errorlevel 1 exit /b 0
echo.
call :DO_GUARD
call :PAUSEIT
exit /b 0

:DO_GUARD
if defined DRYRUN (
    echo    [DRY]  copy self to ProgramData + schtasks /create EdgeUpdateBlockerGuard
    exit /b 0
)
set "GDIR=%ProgramData%\EdgeUpdateBlocker"
if not exist "%GDIR%" md "%GDIR%" >nul 2>&1
copy /y "%~f0" "%GDIR%\guard.bat" >nul 2>&1
if not exist "%GDIR%\guard.bat" (
    echo    [ERR]  复制失败，守护未安装
    exit /b 0
)
schtasks /delete /tn "EdgeUpdateBlockerGuard" /f >nul 2>&1
schtasks /create /tn "EdgeUpdateBlockerGuard" /tr "%GDIR%\guard.bat --guard" /sc minute /mo 60 /ru SYSTEM /f >nul 2>&1
if errorlevel 1 (
    echo    [ERR]  计划任务创建失败（路径含空格时可能如此）
    call :LOG "GUARD CREATE ERR"
) else (
    echo    [OK]   已安装 EdgeUpdateBlockerGuard，每小时加固一次
    call :LOG "GUARD CREATED"
)
exit /b 0


rem ============================================================================
rem  [B] 体检
rem ============================================================================
:SHOW_STATUS
call :BANNER
echo    [B] 运行状态体检  （只读）
call :LINE
call :CHECK_ADMIN
call :CHECK_ONE_SVC "edgeupdate"
call :CHECK_ONE_SVC "edgeupdatem"
call :CHECK_ONE_SVC "MicrosoftEdgeElevationService"
call :LINE
call :CHECK_REG
call :CHECK_PROT
call :CHECK_HOSTS
call :CHECK_FW
call :CHECK_ACL
call :CHECK_REN
call :CHECK_TASKS
call :CHECK_VER
call :LINE
exit /b 0

:CHECK_ADMIN
if "%ISADMIN%"=="1" (
    echo    运行权限      = 管理员（全部功能可用）
) else (
    echo    运行权限      = 非管理员（修改类操作会被拒绝）
)
exit /b 0

:CHECK_ONE_SVC
set "SV=未知"
sc qc %~1 >nul 2>&1
if errorlevel 1 (
    set "SV=服务不存在"
) else (
    set "SV=未禁用"
    for /f "tokens=4" %%A in ('sc qc %~1 2^>nul ^| findstr /i "START_TYPE"') do (
        if /i "%%A"=="DISABLED" (set "SV=已禁用") else (set "SV=%%A")
    )
)
echo    服务 %~1 = !SV!
exit /b 0

:CHECK_REG
set "RV=未写入"
reg query "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v UpdateDefault >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v UpdateDefault 2^>nul ^| findstr /i "UpdateDefault"') do set "RV=UpdateDefault=%%A"
)
echo    组策略        = !RV!
exit /b 0

:CHECK_PROT
set "PV=未开启"
if exist "%PFLAG%" set "PV=已开启（标记）"
set "PSF=%TEMP%\eul_protchk.ps1"
>"%PSF%" echo $p='HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate'
>>"%PSF%" echo if(Test-Path $p){$n=@((Get-Acl $p).Access.Where({$_.AccessControlType -eq 'Deny'})).Count;if($n -gt 0){'已锁死 LOCKED'}else{'未锁 OPEN'}}else{'服务缺失 NA'}
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%PSF%" 2^>nul`) do set "PV=%%A"
if exist "%PSF%" del "%PSF%" >nul 2>&1
echo    服务保护      = !PV!
exit /b 0

:CHECK_HOSTS
set "HV=未屏蔽"
if exist "%HOSTS%" (
    findstr /c:"EdgeUpdateBlocker BEGIN" "%HOSTS%" >nul 2>&1
    if not errorlevel 1 set "HV=已屏蔽 3 条端点"
)
echo    hosts         = !HV!
exit /b 0

:CHECK_FW
set "FV=无规则"
netsh advfirewall firewall show rule name="%FW1%" >nul 2>&1
if not errorlevel 1 set "FV=已拦截 x86"
netsh advfirewall firewall show rule name="%FW2%" >nul 2>&1
if not errorlevel 1 set "FV=!FV! + x64"
echo    防火墙        = !FV!
exit /b 0

:CHECK_ACL
set "AV=目录缺失"
if exist "%EU_X86%" (
    set "AV=可写（未锁）"
    >"%EU_X86%\.eultest.tmp" echo x 2>nul
    if exist "%EU_X86%\.eultest.tmp" (
        del "%EU_X86%\.eultest.tmp" >nul 2>&1
    ) else (
        set "AV=已锁死（拒绝写入）"
    )
)
echo    目录 ACL      = !AV!
exit /b 0

:CHECK_REN
set "NV=未找到更新器"
for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do if exist "%%~D\MicrosoftEdgeUpdate.exe" set "NV=原版存在（未改名）  %%~nxD"
if "%NV%"=="未找到更新器" for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do if exist "%%~D\MicrosoftEdgeUpdate.exe.bak" set "NV=已改名 .bak  %%~nxD"
echo    更新器文件    = !NV!
exit /b 0

:CHECK_TASKS
set "TT=0"
set "TL2=%TEMP%\eul_chk_%RANDOM%.txt"
schtasks /query /fo csv /nh > "%TL2%" 2>nul
if exist "%TL2%" for /f "usebackq delims=" %%A in (`findstr /i /c:"MicrosoftEdgeUpdateTask" "%TL2%" 2^>nul`) do set /a TT+=1
if exist "%TL2%" del "%TL2%" >nul 2>&1
if "%TT%"=="0" (echo    计划任务      = 已清除) else (echo    计划任务      = 仍存在 %TT% 个)
exit /b 0

:CHECK_VER
set "EVER=读取失败"
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\%G_STABLE%" /v pv 2^>nul ^| findstr /i "pv"') do set "EVER=%%A"
echo    当前 Edge     = !EVER!
exit /b 0


rem ============================================================================
rem  [C] 备份
rem ============================================================================
:UI_BACKUP
call :BANNER
echo    [C] 备份当前环境
echo.
if not exist "%BAKDIR%" md "%BAKDIR%" >nul 2>&1
reg export "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" "%BAKDIR%\policy_edgeupdate.reg" /y >nul 2>&1
if not errorlevel 1 (echo    [OK]   policy_edgeupdate.reg) else (echo    [--]   策略键不存在，跳过导出)
copy /y "%HOSTS%" "%BAKDIR%\hosts.orig.bak" >nul 2>&1
echo    [OK]   hosts.orig.bak
sc qc edgeupdate > "%BAKDIR%\svc_edgeupdate.txt" 2>&1
sc qc edgeupdatem > "%BAKDIR%\svc_edgeupdatem.txt" 2>&1
echo    [OK]   服务配置快照
icacls "%EU_X86%" > "%BAKDIR%\acl_edgeupdate.txt" 2>&1
echo    [OK]   ACL 快照
schtasks /query /fo list /v 2>nul | findstr /i /c:"MicrosoftEdgeUpdate" > "%BAKDIR%\tasks_edgeupdate.txt"
echo    [OK]   计划任务快照
echo.
echo    备份目录：%BAKDIR%
echo    还原注册表：双击 .reg 导入即可
call :LOG "BACKUP DONE"
call :PAUSEIT
exit /b 0


rem ============================================================================
rem  [F] 一键还原升级
rem ============================================================================
:UI_UPGRADE
call :BANNER
echo    [F] 一键还原升级
echo.
echo    流程：
echo      1. 解除服务保护 / 目录 ACL / 文件名 / 防火墙 / hosts / 组策略
echo      2. 把 disableEdgeUpdate 目录名改回 EdgeUpdate
echo      3. 服务启动类型恢复「手动」并拉起 edgeupdate
echo      4. 触发更新检查，同时打开 edge://settings/help 看下载进度
echo      5. 升级完成后可一键回锁
echo.
call :ASK "确认开始还原并升级" "Y"
if errorlevel 1 exit /b 0
echo.
call :DO_RESTORE
echo.
call :DO_UPGRADE_TRIGGER
echo.
call :LINE
echo    请在打开的页面确认版本号已变化。
echo    若仍是旧版本：CDN 可能尚未推送，或需完全退出 Edge 后重开。
call :LINE
if defined AUTOPICK exit /b 0
echo.
echo   升级完成后按任意键继续...
pause >nul
echo.
call :ASK "现在重新加锁（回到禁止更新状态）" "Y"
if errorlevel 1 (
    echo.
    echo    [--]   已保持可更新状态，Edge 将恢复正常自动更新。
    call :LOG "UPGRADE-only (no relock)"
    exit /b 0
)
echo.
call :DO_ALL_LAYERS
echo.
call :LINE
echo    [完成] 已重新加锁，八层防护全部生效。
call :LINE
call :LOG "UPGRADE + RELOCK DONE"
call :PAUSEIT
exit /b 0

:DO_UPGRADE_TRIGGER
if defined DRYRUN (
    echo    [DRY]  net start edgeupdate + MicrosoftEdgeUpdate.exe /c + open edge://settings/help
    exit /b 0
)
echo    [..]   拉起更新服务
net start edgeupdate  >nul 2>&1
net start edgeupdatem >nul 2>&1
set "UDIR="
if exist "%EU_X86%\MicrosoftEdgeUpdate.exe" set "UDIR=%EU_X86%"
if not defined UDIR if exist "%EU_ALT%\MicrosoftEdgeUpdate.exe" set "UDIR=%EU_ALT%"
if defined UDIR (
    start "" "%UDIR%\MicrosoftEdgeUpdate.exe" /c
    echo    [OK]   已触发更新器检查
    call :LOG "UPGRADE TRIGGER %UDIR%"
) else (
    echo    [--]   未找到更新器，改由 Edge 自身检查
)
set "MSEXE=%PF86%\Microsoft\Edge\Application\msedge.exe"
if exist "%MSEXE%" (
    start "" "%MSEXE%" "edge://settings/help"
    echo    [OK]   已打开 edge://settings/help
) else (
    echo    [--]   未找到 msedge.exe，请手动打开 edge://settings/help
)
exit /b 0


rem ============================================================================
rem  [D] 还原
rem ============================================================================
:UI_RESTORE
call :BANNER
echo    [D] 恢复还原全部
echo.
echo    顺序：解除服务保护 -^> 守护任务 -^> ACL -^> 文件名 -^> 目录名
echo          -^> 防火墙 -^> hosts -^> 组策略 -^> 服务启动类型
echo.
echo    注意：[D] 只还原、不升级；想立刻拉最新版请用 [F]。
echo.
call :ASK "确认还原（Edge 将恢复自动更新）" "N"
if errorlevel 1 exit /b 0
echo.
call :DO_RESTORE
echo.
call :LINE
echo    [完成] 已还原，Edge 将恢复正常自动更新。
echo           想立刻拉取最新版，请用 [F] 一键还原升级。
call :LINE
call :PAUSEIT
exit /b 0

:DO_RESTORE
if defined DRYRUN (
    echo    [DRY]  restore all layers
    exit /b 0
)
echo    [..]   解除服务保护
call :DO_PROT_OFF

echo    [..]   移除守护任务
schtasks /delete /tn "EdgeUpdateBlockerGuard" /f >nul 2>&1
if exist "%ProgramData%\EdgeUpdateBlocker\guard.bat" del "%ProgramData%\EdgeUpdateBlocker\guard.bat" >nul 2>&1
if exist "%ProgramData%\EdgeUpdateBlocker" rd "%ProgramData%\EdgeUpdateBlocker" >nul 2>&1

echo    [..]   解除目录 ACL
taskkill /f /im MicrosoftEdgeUpdate.exe >nul 2>&1
for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do (
    if exist "%%~D" icacls "%%~D" /remove:d "*S-1-1-0" /T /C /Q >nul 2>&1
)
echo    [OK]   ACL 已还原

echo    [..]   还原更新器文件名
for %%D in ("%EU_X86%" "%EU_ALT%" "%EU_X64%") do (
    if exist "%%~D\MicrosoftEdgeUpdate.exe.bak" (
        ren "%%~D\MicrosoftEdgeUpdate.exe.bak" "MicrosoftEdgeUpdate.exe" >nul 2>&1
        if errorlevel 1 (echo    [ERR]  还原失败："%%~D") else (echo    [OK]   已还原 "%%~D")
    )
)

echo    [..]   还原更新器目录名
if exist "%EU_X86%\MicrosoftEdgeUpdate.exe" (
    echo    [OK]   EdgeUpdate 目录正常
) else (
    if exist "%EU_ALT%\MicrosoftEdgeUpdate.exe" (
        if exist "%EU_X86%" rd "%EU_X86%" >nul 2>&1
        move "%EU_ALT%" "%EU_X86%" >nul 2>&1
        if exist "%EU_X86%\MicrosoftEdgeUpdate.exe" (
            echo    [OK]   disableEdgeUpdate 已改回 EdgeUpdate
            call :LOG "DIRNAME RESTORED"
        ) else (
            echo    [ERR]  目录改名失败，请手动把 disableEdgeUpdate 改为 EdgeUpdate
            call :LOG "DIRNAME RESTORE ERR"
        )
    ) else (
        if exist "%EU_X86%" rd "%EU_X86%" >nul 2>&1
        echo    [--]   系统里没有可用更新器目录，重装 Edge 即可恢复
    )
)

echo    [..]   删除防火墙规则
netsh advfirewall firewall delete rule name="%FW1%" >nul 2>&1
netsh advfirewall firewall delete rule name="%FW2%" >nul 2>&1
echo    [OK]   防火墙规则已移除

echo    [..]   清理 hosts
call :HOSTS_RESTORE

echo    [..]   删除组策略
call :REG_REMOVE "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate"
call :REG_REMOVE "HKLM\SOFTWARE\WOW6432Node\Policies\Microsoft\EdgeUpdate"
echo    [OK]   组策略已移除

echo    [..]   恢复服务启动类型
for %%S in (%SVCLIST%) do (
    sc query %%S >nul 2>&1
    if not errorlevel 1 sc config %%S start= demand >nul 2>&1
)
echo    [OK]   服务已恢复为「手动」

echo    [..]   计划任务说明
echo    [--]   计划任务会在 Edge 下次更新检查时自动重建
echo           要立即重建并升级，请用 [F] 一键还原升级
call :LOG "RESTORE DONE"
exit /b 0

:REG_REMOVE
set "K=%~1"
reg query "%K%" >nul 2>&1
if errorlevel 1 exit /b 0
reg delete "%K%" /v UpdateDefault                /f >nul 2>&1
reg delete "%K%" /v AutoUpdateCheckPeriodMinutes /f >nul 2>&1
reg delete "%K%" /v UpdatesSuppressedDurationMin /f >nul 2>&1
reg delete "%K%" /v UpdatesSuppressedStartHour   /f >nul 2>&1
reg delete "%K%" /v UpdatesSuppressedStartMin    /f >nul 2>&1
reg delete "%K%" /v "Update%G_STABLE%"           /f >nul 2>&1
reg delete "%K%" /v "Update%G_BETA%"             /f >nul 2>&1
reg delete "%K%" /v "Update%G_DEV%"              /f >nul 2>&1
reg delete "%K%" /v "Update%G_CANARY%"           /f >nul 2>&1
reg delete "%K%" /v "Update%G_WEBVIEW2%"         /f >nul 2>&1
exit /b 0


rem ============================================================================
rem  非交互入口
rem ============================================================================
:RUN_STATUS
call :BANNER
echo    只读体检模式（不修改任何设置）
call :LINE
call :CHECK_ADMIN
call :CHECK_ONE_SVC "edgeupdate"
call :CHECK_ONE_SVC "edgeupdatem"
call :CHECK_ONE_SVC "MicrosoftEdgeElevationService"
call :LINE
call :CHECK_REG
call :CHECK_PROT
call :CHECK_HOSTS
call :CHECK_FW
call :CHECK_ACL
call :CHECK_REN
call :CHECK_TASKS
call :CHECK_VER
call :LINE
exit /b 0

:RUN_AUTO
call :BANNER
echo    自动模式：执行最强组合
call :LINE
call :DO_SVC
echo.
call :DO_TASK
echo.
call :DO_REG
echo.
call :DO_REN
echo.
call :DO_ACL
echo.
call :DO_PROT_ON
echo.
call :DO_HOSTS
echo.
call :DO_FW
echo.
call :LINE
echo    [完成] 八层防护已叠加，日志：%LOGF%
call :LINE
call :PAUSEIT
exit /b 0

:RUN_UPGRADE
call :BANNER
echo    自动模式：还原并升级
call :LINE
call :DO_RESTORE
echo.
call :DO_UPGRADE_TRIGGER
echo.
call :LINE
echo    [完成] 已还原并触发升级，请在 edge://settings/help 查看进度。
call :LINE
call :PAUSEIT
exit /b 0

:RUN_GUARD
set "DRYRUN="
call :DO_SVC  >nul 2>&1
call :DO_TASK >nul 2>&1
call :DO_REG  >nul 2>&1
call :LOG "GUARD RUN"
exit /b 0

:SHOW_HELP
echo.
echo    Edge Update Blocker v%APP_VER%
echo.
echo    用法：
echo      EdgeUpdateBlocker.bat            交互菜单
echo      EdgeUpdateBlocker.bat --auto     最强组合（八层）
echo      EdgeUpdateBlocker.bat --status   只读体检
echo      EdgeUpdateBlocker.bat --dryrun   空跑演练
echo      EdgeUpdateBlocker.bat --upgrade  一键还原并升级到最新版
echo      EdgeUpdateBlocker.bat --guard    静默加固
echo      EdgeUpdateBlocker.bat --help     本帮助
echo.
echo    参考：
echo      Windows Update Blocker (Sordum)  - Protect Service Settings
echo      github.com/Vikindor/disable-edge-update
echo      github.com/jiarandiana0307/edge-update-switch
echo      github.com/PartakithRC1/Win11-EdgeBGone
echo      learn.microsoft.com/deployedge/microsoft-edge-update-policies
echo.
exit /b 0


rem ============================================================================
rem  [E] 说明
rem ============================================================================
:SHOW_DOC
call :BANNER
echo    [E] 风险与原理
call :LINE
echo    为什么单招都不彻底？
echo.
echo    Edge 更新有三条独立入口：
echo      1. edgeupdate / edgeupdatem 服务（SCM 拉起）
echo      2. MicrosoftEdgeUpdateTask* 计划任务（不经服务直接跑）
echo      3. EdgeUpdater 由浏览器自身或 WebView2 应用唤起
echo   而 Windows 大版本更新会把服务与任务全部重建，
echo    所以要「服务 + 任务 + 策略 + 文件 + 注册表保护」叠加。
echo.
call :LINE
echo    各手段可靠性（由强到弱）
echo.
echo      服务注册表保护 [8]    最强，防回滚，WUB 同款
echo      目录 ACL 锁死  [6]    极强，副作用是卸载/修复失败
echo      组策略 [3]            正规，微软文档支持，无副作用
echo      服务禁用 [1]          有效，会被系统更新重建
echo      任务清除 [2]          有效，会被 Edge 重建
echo      更新器改名 [7]        有效，大版本可能补回
echo      防火墙 [5]            兜底，防已启动的更新器联网
echo      hosts [4]             最弱，仅拦 DNS 层
echo.
call :LINE
echo    已知副作用
echo.
echo    - 必须以管理员身份运行，否则所有修改都不会生效（本程序已强制校验）
echo    - WebView2 默认不冻结（Teams/Office 等依赖它）
echo    - 目录锁死后卸载/修复 Edge 会报错，先用 [D] 还原
echo    - 服务保护开启后，[1] 会改不动服务，属正常
echo    - 长期不更新有安全风险，建议每季度手动更新一次：
echo        edge://settings/help
echo    - 企业环境请走组策略/Intune 下发，不要用本脚本
echo.
call :LINE
call :PAUSEIT
exit /b 0
