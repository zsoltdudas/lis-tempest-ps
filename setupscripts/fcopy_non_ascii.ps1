param([string] $filePath)

# Sample string with non-ascii chars
$nonAsciiChars="¡¢£¤¥§¨©ª«¬®¡¢£¤¥§¨©ª«¬®¯±µ¶←↑ψχφυ¯±µ¶←↑ψ¶←↑ψχφυ¯±µ¶←↑ψχφυχφυ"

# Create a ~2MB sample file with non-ascii characters
$stream = [System.IO.StreamWriter] $filePath
1..8000 | % {
    $stream.WriteLine($nonAsciiChars)
}
$stream.close()

# Checking if sample file was successfully created
if (-not $?){
    return $False   
}

return $True