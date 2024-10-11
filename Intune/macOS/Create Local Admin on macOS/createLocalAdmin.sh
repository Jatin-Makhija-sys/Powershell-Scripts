#!/bin/sh
accountname=cloudinfraadmin
password="C0mputer@2020"
dscl . -create /Users/$accountname
dscl . -create /Users/$accountname UserShell /bin/bash
dscl . -create /Users/$accountname RealName "CloudInfra Admin Account"
dscl . -create /Users/$accountname UniqueID "2001"
dscl . -create /Users/$accountname PrimaryGroupID 20
dscl . -create /Users/$accountname NFSHomeDirectory /Users/$accountname
dscl . -passwd /Users/$accountname $password
dscl . -create /Users/$accountname hint "computer"
dscl . -append /Groups/admin GroupMembership $accountname