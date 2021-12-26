--[[
SOURCE_ https://github.com/elig0n/mpv-open-file-dialog
COMMIT_20200415_373e7fa

To the extent possible under law, the author(s) have dedicated all copyright
and related and neighboring rights to this software to the public domain
worldwide. This software is distributed without any warranty. See
<https://creativecommons.org/publicdomain/zero/1.0/> for a copy of the CC0
Public Domain Dedication, which applies to this software.

自定义快捷键 在mpv中唤起一个打开文件的窗口用于快速加载文件
示例：在 input.conf 中单独另起写入下一行的内容即为该按键方案打开对话框
CTRL+o   script-binding   open_file/open_dialog
]]--

utils = require 'mp.utils'

function is_windows()
  local windir = os.getenv("windir")
  if windir~=nil then
    return true
  else
    return false
  end
end

function open_dialog_windows()
	local was_ontop = mp.get_property_native("ontop")
	if was_ontop then mp.set_property_native("ontop", false) end
	local res = utils.subprocess({
		args = {'powershell', '-NoProfile', '-Command', [[& {
			Trap {
				Write-Error -ErrorRecord $_
				Exit 1
			}
			Add-Type -AssemblyName PresentationFramework

			$u8 = [System.Text.Encoding]::UTF8
			$out = [Console]::OpenStandardOutput()

			$ofd = New-Object -TypeName Microsoft.Win32.OpenFileDialog
			$ofd.Multiselect = $true

			If ($ofd.ShowDialog() -eq $true) {
				ForEach ($filename in $ofd.FileNames) {
					$u8filename = $u8.GetBytes("$filename`n")
					$out.Write($u8filename, 0, $u8filename.Length)
				}
			}
		}]]},
		cancellable = false,
	})
	if was_ontop then mp.set_property_native("ontop", true) end
	if (res.status ~= 0) then return end

	local first_file = true
	for filename in string.gmatch(res.stdout, '[^\n]+') do
		mp.commandv('loadfile', filename, first_file and 'replace' or 'append')
		first_file = false
	end
end

function open_dialog_linux()
	local was_ontop = mp.get_property_native("ontop")
	if was_ontop then mp.set_property_native("ontop", false) end
    local res = utils.subprocess({ args = {"yad", "--file"}, capture_stdout='yes', capture_stderr='yes', cancellable = false, })
	if was_ontop then mp.set_property_native("ontop", true) end
	if (res.status ~= 0) then print("bad return code") return end

	local first_file = true
	for filename in string.gmatch(res.stdout, '[^\n]+') do
		mp.commandv('loadfile', filename, first_file and 'replace' or 'append')
		first_file = false
	end
end

function open_dialog()
    if is_windows() then
        open_dialog_windows()
    else
        open_dialog_linux()
    end
end

mp.add_key_binding(nil, 'open_dialog', open_dialog)
