<#
.SYNOPSIS
    Creates a WDAC/App Control for Business supplemental policy that allows Google Chrome 
    to run by defining a Publisher rule.

.DESCRIPTION
    This script generates a supplemental ACfB policy for Google Chrome. 
    It scans the Chrome installation directory, builds Publisher-level rules (with hash fallback), 
    associates the supplemental policy with the specified base policy using its PolicyID, 
    and compiles the XML into a deployable CIP/BIN file.

.PARAMETER $scanPath
    The file path to the Google Chrome installation directory that will be scanned to create allow rules.

.PARAMETER $outXml
    The output path where the generated XML policy file will be saved.

.PARAMETER $baseId
    The PolicyID of the base policy this supplemental policy should be linked to.

.PARAMETER $outBin
    The output path where the compiled CIP/BIN file will be saved.

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.0

.EXAMPLE
    To generate a supplemental policy allowing Google Chrome:
    .\ACfB_Allow_Chrome_Supplemental.ps1
    
    This will create an XML and a compiled CIP file that can be deployed through Intune or another 
    management solution as a supplemental policy to the existing base policy.
#>

# Create a supplemental policy that allows Google Chrome by Publisher
$scanPath = "C:\Program Files\Google\Chrome\Application"   # adjust if needed
$outXml   = "C:\Temp\ACfB_Allow_Chrome_Supplemental.xml"
New-CIPolicy -FilePath $outXml -ScanPath $scanPath -Level Publisher -UserPEs -Fallback Hash

# Mark it as a supplemental policy (Link it to your base by BasePolicyID)
# Replace the GUID below with your base policy’s PolicyID
$baseId = '{030A293A-FC23-4402-A2AE-CDD924FEED5A}'
Set-CIPolicyIdInfo -FilePath $outXml -SupplementsBasePolicyID $baseId

# Compile to CIP/BIN
$outBin = "C:\temp\ACfB_Allow_Chrome_Supplemental.cip"
ConvertFrom-CIPolicy -XmlFilePath $outXml -BinaryFilePath $outBin