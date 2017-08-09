function getKeyboard($vmName)
{
    $filt = "elementname='$vmName'"
    $cs = gwmi -computername "." -Namespace root\virtualization\v2 -class Msvm_computersystem -filter $filt
    $path = ${cs}.path.path
    $query2 = "ASSOCIATORS OF {$path} WHERE resultClass = Msvm_Keyboard"
    $Keyboard = gwmi -computerName "." -Namespace "root\virtualization\v2" -Query $query2
    return $Keyboard
}

function sendKey($vmName, [int]$keyNum)
{
    $Keyboard = getKeyboard $vmName
    #$Keyboard.InvokeMethod("TypeText","Hellow world!") # Type 'Hello World!'
    $Keyboard.InvokeMethod("TypeKey", $keyNum) # Press enter
}

function sendScancodes($vmName, [byte[]]$keys)
{
    $Keyboard = getKeyboard $vmName
    $Keyboard.TypeScanCodes($keys) # Press enter
}


function sendText($vmName, $txt)
{
    $keyboard = getKeyboard $vmName
    $keyboard.InvokeMethod("TypeText", $txt)
}

function login($vmName)
{
   # send 'test' as user
   sendKey $vmName 0x54
   sendKey $vmName 0x45
   sendKey $vmName 0x53
   sendKey $vmName 0x54
   sendKey $vmName 0x0D
   # send '123' as passwd
   sendKey $vmName 0x31
   sendKey $vmName 0x32
   sendKey $vmName 0x33
   sendKey $vmName 0x0D
}

function simulateVI($vmName)
{
   # send 'vi t' to open file
   sendKey $vmName 0x56
   sendKey $vmName 0x49
   sendKey $vmName 0x20
   sendKey $vmName 0x54
   sendKey $vmName 0x0D
   # send 'insert' 
   sendKey $vmName 0x2D
   # send '0123456789' as input
   sendKey $vmName 0x30
   sendKey $vmName 0x31
   sendKey $vmName 0x32
   sendKey $vmName 0x33
   sendKey $vmName 0x34
   sendKey $vmName 0x35
   sendKey $vmName 0x36
   sendKey $vmName 0x37
   sendKey $vmName 0x38
   sendKey $vmName 0x39
   # send 'ESC'
   sendScancodes $vmName @([byte]1)
   # send ':'
   sendScancodes $vmName @([byte]42,[byte]39)
   # send 'x'
   sendKey $vmName 0x58
   sendKey $vmName 0x0D
}

$vmName = "hz_frbsd_gen2"
#$vmName = "hz_FreeBSD11_alpha"
#login $vmName
#simulateVI $vmName
sendText $vmName "Hello"

#test2 $vmName
#sendKey $vmName 0x14
#sendKey $vmName 0x58
#sendKey $vmName 0x14
#sendScancodes $vmName @([byte]42,[byte]39)
#sendScancodes $vmName @([byte]42,[byte]39)
# send 'x'
#sendKey $vmName 0x58
#sendScancodes $vmName @([byte]45)#,[byte]45)
