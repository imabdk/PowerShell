<#
.DESCRIPTION
    When forcing TLS encryption on outgoing e-mails due to GDPR requirements, Exchange Online will try sending the e-mail for 24 hours before dropping it and returning a default NDR (non-delivery report).

    Waiting 24 hours to get informed if your e-mail was delivered or not is not ideal, thus this script was created.

    The script will run on a schedule (say every 15 minutes) and look for e-mails send and recieved in the past 16 minutes. 
    If any of the e-mails in those past 16 minutes are delayed due to lack of TLS support with the recipient, the script will send a custom e-mail to the sender right away.

.NOTES
    Filename: Get-EmailsNotSendUsingTLS.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

    Version history:

    1.0   -   Script created
    
.LINK

#>

# Azure automation credentials
# EDIT these to match your own credentials
$AzureCredentials = Get-AutomationPSCredential -Name "AzureAutomation"
$hlpCredentials = Get-AutomationPSCredential -Name "hlp"

# Connect to the Exchange Online Management module (this is available in the module gallery in Azure Automation)
if (Get-Module -Name ExchangeOnlineManagement -ListAvailable) {
    try {
        Write-Verbose -Verbose -Message "Connecting to Exchange Online using $AzureCredentials"
        Connect-ExchangeOnline -Credential $AzureCredentials -ShowProgress $true
        Write-Verbose -Verbose -Message "Successfully connected to Exchange Online"
    }
    catch {
        Write-Verbose -Verbose -Message "Failed to connect to Exchange Online. Please check if credentials and permissions are correct. Breaking script"
        break
    }
}
elseif (-NOT(Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    Write-Verbose -Verbose -Message "The Exchange Online module is not available. Breaking script"
    break  
}

# Office 365 and other variables
# EDIT this to suit your needs
$emailSmtp = "smtp.office365.com"
$emailPort = "587"
$emailFrom = "hlp@imab.dk"
$emailSubject = "E-mail sent without encryption!"
$emailBcc = "bcc1@imab.dk", "bcc2@imab.dk"
$url = "https://imab.dk"
$automaticReply = "Automatic reply:*"
$sendingDomain = "*@imab.dk"

# Reasons reported when e-mails are pending due to lack of TLS support
# These are the reasons report I have found. Maybe there is more? If so, they can easily be added
$reason0 = "Cannot connect to remote server"
$reason1 = "STARTTLS is required to send mail"
$reason2 = "Security status InvalidToken"

# Format date and time
# This is where we configure how far back the script will look for e-mails, which is currently 16 minutes
$localCulture = Get-Culture
$regionDateFormat = [System.Globalization.CultureInfo]::GetCultureInfo($LocalCulture.LCID).DateTimeFormat.LongDateTimePattern
$dateEnd = Get-Date -f $RegionDateFormat
$dateStart = $dateEnd.AddMinutes(-16)

# Get all emails from the last 16 minutes which are pending and not an automatic reply
# Automatic replies are filtered out. We don't want to trigger an e-mail based on an out of office reply
$emailsPending = @()
$emailsPending = Get-MessageTrace -StartDate $dateStart.ToUniversalTime() -EndDate $dateEnd.ToUniversalTime() | Where-Object {$_.Status -eq "Pending" -AND $_.Subject -notlike $automaticReply} | Select-Object Received,SenderAddress,RecipientAddress,MessageTraceID,Subject

# Loop through each e-mail found
Write-Verbose -Verbose -Message "Looping through each e-mail message with a status of pending in the Exchange Online queue"
foreach ($email in $emailsPending) {
    
    $timestamp = $email.Received
    $sender = $email.SenderAddress
    $recipient = $email.RecipientAddress
    $messageId = $email.MessageTraceId
    $subject = $email.Subject

    # Get further message details from each e-mail
    # This is needed to see the exact cause of why the email is pending
    try {
        $result = Get-MessageTraceDetail -SenderAddress $sender -RecipientAddress $recipient -MessageTraceId $messageid
    }
    catch { }

    # Loop through each event on each e-mail
    foreach ($event in $result.Event) {
        
        # Only grab e-mails which have a status equal to Defer. This indicates e-mails being delayed for various reasons
        if ($event -eq "Defer") {
            
            # Loop through each line of details
            foreach ($detail in $result.Detail) {
                
                # Sorting out empty lines of details
                if ($detail -ne $null) {

                    # Sorting again, only grabbing e-mails which matches the reasons for being delayed due to lack of TLS support with the recipient
                    if (($detail -match $reason1) -AND ($detail -match $reason0)) {
                        
                        # E-mail being sent internally in the sending domain is not interesting. Only grabbing e-mails going out externally
                        if (($sender -like $sendingDomain) -AND ($recipient -notlike $sendingDomain)) {

                            Write-Verbose -Verbose -Message "*** E-mail found which matches all the criteria ***" 
                            Write-Verbose -Verbose -Message "Sender is: $sender recipient is: $recipient subject is: $subject MessageID is: $messageId"

                            # Creating e-mail body including stylesheet
                            $emailBody = "
                            <html>
                                <head>
                                    <style type='text/css'>
                                    h1 {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 20px;
                                    }

                                    h2 {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 15px;
                                    }

                                    body {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 13px;
                                    }
                                    </style>
                                </head>
                            <body>
                                <h1>Attention: Your e-mail has NOT been delivered!</h1>
								<p>Your e-mail sent to $recipient, sent on $timestamp (UTC+0), with the subject: '$subject', has not been delivered.</p>

                                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce at ultricies erat. Duis ac aliquet massa. Vestibulum bibendum at velit vel volutpat.<br>
                                Donec vel orci tristique, pulvinar felis nec, finibus quam. Phasellus pulvinar leo est, et efficitur eros sollicitudin non. Nunc congue porta eleifend.<br> 
                                Pellentesque aliquet sagittis egestas. Nam eget efficitur mauris. Maecenas at commodo nisi. Pellentesque fermentum neque posuere convallis congue.<br> 
                                Curabitur eu diam risus. Proin ipsum eros, pellentesque nec tempus non, feugiat consectetur tortor.</p>

								<p>Best regards,<br><a href=$url>www.imab.dk</a></p>
                            </body>
                            </html>
                            "
                            
                            # Try sending the e-mail using the SMTP details provided                            
                            try {
                                Write-Verbose -Verbose -Message "Sending a custom bounce e-mail to $sender, notifying him/her about the lack of encryption support with the recipient at $recipient"
                                Send-MailMessage -To $sender -From $emailFrom -Subject $emailSubject -Body $emailBody -Credential $hlpCredentials -SmtpServer $emailSmtp -Port $emailPort -Priority High -Encoding Unicode -UseSsl -BodyAsHtml
                            }
                            catch {
                                Write-Verbose -Verbose -Message "Failed to send the e-mail to $sender"
                            }
                        }
                    }

                    # Looking for a third reason to the email being delayed (reason2)
                    elseif (($detail -match $reason0) -AND ($detail -match $reason2)) {

                        # E-mail being sent internally in the sending domain is not interesting. Only grabbing e-mails going out externally
                        if (($sender -like $sendingDomain) -AND ($recipient -notlike $sendingDomain)) {

                            Write-Verbose -Verbose -Message "*** E-mail found which matches all the criteria ***" 
                            Write-Verbose -Verbose -Message "Sender is: $sender recipient is: $recipient subject is: $subject MessageID is: $messageId"

                            # Creating e-mail body including stylesheet
                            $emailBody = "
                            <html>
                                <head>
                                    <style type='text/css'>
                                    h1 {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 20px;
                                    }

                                    h2 {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 15px;
                                    }

                                    body {
                                        color: #002933;
                                        font-family: verdana;
                                        font-size: 13px;
                                    }
                                    </style>
                                </head>
                            <body>
                                <h1>Attention: Your e-mail has NOT been delivered!</h1>
								<p>Your e-mail sent to $recipient, sent on $timestamp (UTC+0), with the subject: '$subject', has not been delivered.</p>

                                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce at ultricies erat. Duis ac aliquet massa. Vestibulum bibendum at velit vel volutpat.<br>
                                Donec vel orci tristique, pulvinar felis nec, finibus quam. Phasellus pulvinar leo est, et efficitur eros sollicitudin non. Nunc congue porta eleifend.<br> 
                                Pellentesque aliquet sagittis egestas. Nam eget efficitur mauris. Maecenas at commodo nisi. Pellentesque fermentum neque posuere convallis congue.<br> 
                                Curabitur eu diam risus. Proin ipsum eros, pellentesque nec tempus non, feugiat consectetur tortor.</p>

								<p>Best regards,<br><a href=$url>www.imab.dk</a></p>
                            </body>
                            </html>
                            "
                            
                            # Try sending the e-mail using the SMTP details provided                            
                            try {
                                Write-Verbose -Verbose -Message "Sending a custom bounce e-mail to $sender, notifying him/her about the lack of encryption support with the recipient at $recipient"
                                Send-MailMessage -To $sender -From $emailFrom -Subject $emailSubject -Body $emailBody -Credential $hlpCredentials -SmtpServer $emailSmtp -Port $emailPort -Priority High -Encoding Unicode -UseSsl -BodyAsHtml
                            }
                            catch {
                                Write-Verbose -Verbose -Message "Failed to send the e-mail to $sender"
                            }
                        }
                    }
                }
            }
        }
    }
}
Write-Verbose -Verbose -Message "Script has completed"
