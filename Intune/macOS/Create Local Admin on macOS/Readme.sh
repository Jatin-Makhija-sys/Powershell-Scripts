Script header (System shell)
#!/bin/sh

#Modify accountname and password variables as per your requirement
accountname=cloudinfraAdmin
password="C0mputer@2020"

#Create a new user account
dscl . -create /Users/$accountname

#Set the default shell for this user as /bin/bash
dscl . -create /Users/$accountname UserShell /bin/bash

#Add full name or display name for this user
dscl . -create /Users/$accountname RealName "CloudInfra Admin Account"

#Provide a Unique ID for this user account
dscl . -create /Users/$accountname UniqueID "2001"

#Set PrimaryGroup ID to 20 for admin accounts and 80 is for Standard accounts
dscl . -create /Users/$accountname PrimaryGroupID 20

#Set the Home directory for the user
dscl . -create /Users/$accountname NFSHomeDirectory /Users/$accountname

#Set User account password
dscl . -passwd /Users/$accountname $password

#Add the user to the admin group
dscl . -append /Groups/admin GroupMembership $accountname

#Add the user's profile picture (Optional)
dscl . -create /Users/$accountname picture “/profilepic.png”  

#Add a Password hint for the user (Optional)
dscl . -create /Users/$accountname hint “Provide Password hint” 

#Hide the user on the macOS login window (Optional)
dscl . -create /Users/$accountname IsHidden 1
