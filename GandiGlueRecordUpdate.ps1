Param()

###############################################################################
### Globals ###################################################################
###############################################################################

## This is the path where statuses and information will be logged
$LOG_FILE_PATH = '<path-to-log-file>'

## This is the API key you will need from Gandi to run these operations
## This must be an XML-RPC v4 API KEY
$GANDI_API_KEY = '<gandi-xml-rpc-api-key>'

## This is an array of FQDN glue records you want updated
$GANDI_GLUE_RECORDS = @(
    'ns1.<domain>.<tld>',
    'ns2.<domain>.<tld>'
)

## This is the default endpoint for the Gandi v4 XML-RPC API
$GANDI_API_ENDPOINT = 'https://rpc.gandi.net/xmlrpc/'

## This web-service will load your IPv4 address
$WEB_SERVICE_IPv4 = 'http://v4.ipv6-test.com/api/myip.php'

## This web-service will load your IPv6 address
$WEB_SERVICE_IPv6 = 'http://v6.ipv6-test.com/api/myip.php'

###############################################################################
### Functions/Helpers #########################################################
###############################################################################

Function Log-Append {
    
    [CmdletBinding()]
    [OutputType(
        [Void]
    )]

    Param (
        [String] $Message
    )

    Begin {}

    Process {
        ## Write to the log file
        Add-Content -Path $LOG_FILE_PATH $((Get-Date).ToString() + ' - ' + $Message)
    }

    End {}

}

Function Write-XmlToScreen {
    
    [CmdletBinding()]
    [OutputType(
        [Void]
    )]

    Param (
        [xml] $Xml
    )

    Begin {}

    Process {
        ## Define our string writer
        $stringWriter = New-Object System.IO.StringWriter
        ## Define our XML writer
        $xmlWriter = New-Object System.Xml.XmlTextWriter $stringWriter
        ## We want the XML formatted
        $xmlWriter.Formatting = System.Xml.Formatting.Indented
        ## We want tables
        $xmlWriter.Indentation = 4;
        ## Write the XML
        $Xml.WriteTo($xmlWriter)
        ## Flush the writer
        $xmlWriter.Flush()
        ## Flush the string writer
        $stringWriter.Flush()
        ## Output the XML string
        Write-Output $stringWriter.ToString()
    }

    End {}
}

Function Gandi-SendRequest {
    
    [CmdletBinding()]
    [OutputType(
        [xml]
    )]

    Param (
        [String] $XmlRequestBody
    )

    Begin {}

    Process {
        ## Define our headers container    
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        ## Define the content type
        $headers.Add('Content-Type', 'text/xml')
        ## Define the content length
        $headers.Add('Content-Length', $XmlRequestBody.Length)
        ## Invoke the method
        $xmlResponse = Invoke-RestMethod -Uri $GANDI_API_ENDPOINT -Headers $headers -Method Post -Body $XmlRequestBody
        ## We're done, return the response
        Return [xml] $xmlResponse
    }

    End {}
}

Function Gandi-GetApiVersion {
    
    [CmdletBinding()]
    [OutputType(
        [String]
    )]
  
    Param ()

    Begin {
        ## Define our XML Request
        $xmlRequestBody = ('<?xml version="1.0"?><methodCall><methodName>version.info</methodName><params><param><value><string>' + $GANDI_API_KEY + '</string></value></param></params></methodCall>')
    }

    Process {
        ## We're done, return the API version
        Return ((Gandi-SendRequest -XmlRequestBody $xmlRequestBody).SelectSingleNode('//member/value/string').InnerText)
    }

    End {}
}

Function Gandi-UpdateGlueRecord {
    
    [CmdletBinding()]
    [OutputType(
        [String]
    )]

    Param (
        [String] $GlueRecord,
        [String] $IPv4,
        [String] $IPv6
    )

    Begin {
        ## Define our XML Request
        $xmlRequestBody = ('<?xml version="1.0"?><methodCall><methodName>domain.host.update</methodName><params><param><value><string>' + $GANDI_API_KEY + '</string></value></param><param><value><string>' + $GlueRecord + '</string></value></param><param><array><data><value><string>' + $IPv4 + '</string></value><value><string>' + $IPv6 + '</string></value></data></array></param></params></methodCall>')
    }

    Process {
        ## Localize the response
        $xmlResponse = (Gandi-SendRequest -XmlRequestBody $xmlRequestBody)
        ## Localize the step
        $step = $xmlResponse.SelectSingleNode('//member[8]/value').InnerText
        ## Localize the ETA
        $eta = $xmlResponse.SelectSingleNode('//member[9]/value/int').InnerText
        ## Return the string
        Return ($GlueRecord + ' - Step:  ' + $step + ' ETA:  ' + $eta)
    }

    End {}
}

###############################################################################
### Main Event Loop ###########################################################
###############################################################################

## Define our IPv4 container
$ipv4 = ''
## Define our IPv6 container
$ipv6 = ''
## Load our IPv4 address
$requestIPv4 = Invoke-WebRequest -Uri $WEB_SERVICE_IPv4 -Method Get
## Make sure everything went well
if ($requestIPv4.StatusCode -ne 200) {
    ## Log the message
    Log-Append -Message ('Failed to load IPv4:  ' + $requestIPv4.StatusDescription)
    ## We're done
    Exit
}
## Load our IPv6 address
$requestIPv6 = Invoke-WebRequest -Uri $WEB_SERVICE_IPv6 -Method Get
## Make sure everything went well
if ($requestIPv6.StatusCode -ne 200) {
    ## Log the message
    Log-Append -Message (' - Failed to load IPv6:  ' + $requestIPv4.StatusDescription)
    ## We're done
    Exit
}
## Localize the IPv4
$ipv4 = $requestIPv4.Content
## Localize the IPv6
$ipv6 = $requestIPv6.Content
## Load the API version
$apiVersion = Gandi-GetApiVersion
## Log the IPv4
Log-Append -Message ('Current IPv4:  ' + $ipv4)
## Log the IPv6
Log-Append -Message ('Current IPv6:  ' + $ipv6)
## Log the API version
Log-Append -Message ('Gandi API Version:  ' + $apiVersion)
## Iterate over the glue records
foreach ($record in $GANDI_GLUE_RECORDS) {
    ## Update the record
    $recordUpdate = Gandi-UpdateGlueRecord -GlueRecord $record -IPv4 $ipv4 -IPv6 $ipv6
    ## Log the result
    Log-Append -Message $recordUpdate
}

###############################################################################
### End #######################################################################
###############################################################################
