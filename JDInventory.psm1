$messages = DATA { 
# culture='en-US'
    ConvertFrom-StringData @'
        Verbose_TestConnection = Testing connection to
        Verbose_UseComputer = Starting retrieve information from computer
        Verbose_ConnectionSuccess = Success connection to:
        Warning_Connection = Computer unavailable:
        Warning_Access = Maybe you are not authorized to receive information from the computer. Either you entered the correct username / password. Access is denied to 
'@
}
Import-LocalizedData -BindingVariable messages 

function Get-JDDiskDrive
{
#.ExternalHelp JDInventory.Help.xml
	[CmdletBinding()]
	param(
		[Parameter(Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("CN","Computer","IpAdress")]
        [string[]]$ComputerName = 'localhost',

        [System.Management.Automation.PSCredential]$Credential
	)
    PROCESS 
    {
        foreach ($Computer in $ComputerName)
        {
            if (checkComputerConnection $Computer)
            {
                try
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $WMI_LD = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = '3'" -ComputerName $Computer
                    }
                    elseif ( $PSBoundParameters['Credential'] )
                    {
                        $WMI_LD = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = '3'" -ComputerName $Computer -Credential $Credential
                    }
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Warning "$($messages.Warning_Access) $Computer."
                }
                finally
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer -Verbose:$false).ComputerName
                    }
                    elseif ( $PSBoundParameters['Credential'] )
                    { 
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer -Credential $Credential -Verbose:$false).ComputerName
                    }
                    Foreach ($Volume in $WMI_LD)
		            {
			            $props = @{ 'ComputerName' = $CompName
			                          'DeviceID' = $Volume.DeviceID
				                    'VolumeName' = $Volume.VolumeName
				                   'VolumeDirty' = $Volume.VolumeDirty
				                          'Size' = $Volume.Size
				                     'FreeSpace' = $Volume.FreeSpace
				                   'PercentFree' = $("{0:P}" -f $($Volume.FreeSpace / $Volume.Size))
                                     'Collected' = Get-Date -UFormat "%Y-%m-%d %R"
                                    'FileSystem' = $Volume.FileSystem
                                    'DriveType'  = $volume.DriveType }
                    
                        $obj = New-Object PSObject -Property $props
                        $obj.psobject.typenames.insert(0,'Report.DiskDrive')
                        Write-Output $obj
                    
                    }#End foreach Volume
                }
            }
        }#End foreach Computer 
    }#End PROCESS block
}

function Get-JDNetworkAdapter
{
#.ExternalHelp JDInventory.Help.xml 
    [CmdletBinding()]
	param(
		[Parameter(Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("CN","Computer","IpAdress")]
        [string[]]$ComputerName = 'localhost',

        [System.Management.Automation.PSCredential]$Credential
	)
    PROCESS 
    {
        foreach ($Computer in $ComputerName)
        {
            if (checkComputerConnection $Computer)
            {
                try
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $WMI_NA = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $Computer -ErrorAction Stop
                        $WMI_NAC = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=$true" -ComputerName $Computer -ErrorAction Stop
                    }
                    elseif ( $PSBoundParameters['Credential'] )
                    {
                        $WMI_NA = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                        $WMI_NAC = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=$true" -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                    }
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Warning "$($messages.Warning_Access) $Computer."
                }
                finally
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer).ComputerName
                    }
                    elseif ( $PSBoundParameters['Credential'] )
                    { 
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer -Credential $Credential).ComputerName
                    }
                    Foreach ($NAC in $WMI_NAC)
		            {
			            $NetAdap = $WMI_NA | Where-Object {$NAC.Index -eq $_.Index}
                        if(-not $PSBoundParameters['Credential'])
                        {
                            $BuildNumber = (Get-JDComputerInfo -ComputerName $Computer).BuildNumber
                        }
                        elseif($PSBoundParameters['Credential'])
                        {
                            $BuildNumber = (Get-JDComputerInfo -ComputerName $Computer -Credential $Credential).BuildNumber
                        }
                    
                        if( $BuildNumber -ge 6001 )
			            {
				            $PhysAdap = $NetAdap.PhysicalAdapter
				            $Speed    = "{0:0} Mbit" -f $($NetAdap.Speed / 1000000)
			            }#End If ($WinBuild -ge 6001)
			            else
			            {
				            $PhysAdap = "**Unavailable**"
				            $Speed    = "**Unavailable**"
		                }#End Else

                        $props = @{ 'MACAddress' = $NAC.MACAddress
	                                   'IPAddress' = $NAC.IPAddress
	                                'IPSubnetMask' = $NAC.IPSubnet
	                              'DefaultGateway' = $NAC.DefaultIPGateway
	                              'DNSServerOrder' = $NAC.DNSServerSearchOrder
	                             'DNSSuffixSearch' = $NAC.DNSDomainSuffixSearchOrder
	                             'PhysicalAdapter' = $PhysAdap
	                                       'Speed' = $Speed
                                    'ComputerName' = $CompName
                                         'NICName' = $NetAdap.Name
	                             'NICManufacturer' = $NetAdap.Manufacturer
	                                 'DHCPEnabled' = $NAC.DHCPEnabled
                                 'NetConnectionID' = $NetAdap.NetConnectionID
                                       'Collected' = Get-Date -UFormat "%Y-%m-%d %R";}

                        $obj = New-Object -TypeName PsObject -Property $props
                        $obj.psobject.typenames.insert(0,'Report.NetworkAdapter')
                        Write-Output $obj

                    }#End foreach Nic
                }
            }
        }#End foreach Computer
    }
}

function Get-JDComputerInfo
{
#.ExternalHelp JDInventory.Help.xml
	[CmdletBinding()]
	param(
		[Parameter(Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("CN","Computer","IpAdress")]
        [string[]]$ComputerName= 'localhost',

        [System.Management.Automation.PSCredential]$Credential
	)
    PROCESS 
    {
        foreach ($Computer in $ComputerName)
        {
            if (checkComputerConnection $Computer)
            {
                try
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $WMI_CS = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -ErrorAction Stop
                        $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop
                        $WMI_PR = Get-WmiObject -Class Win32_Processor -ComputerName $Computer -ErrorAction Stop
                    }
                    elseif($PSBoundParameters['Credential'])
                    {
                        $WMI_CS = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                        $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                        $WMI_PR = Get-WmiObject -Class Win32_Processor -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                    }
                    $Show_output = $true
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Warning "$($messages.Warning_Access) $Computer."
                }
                finally
                {
                    $props = @{  'Domain' = $WMI_CS.Domain;
                            'Manufacturer' = $WMI_CS.Manufacturer;
                                   'Model' = $WMI_CS.Model;
                            'ComputerName' = $WMI_CS.Name;
                     'TotalPhysicalMemory' = [int]($WMI_CS.TotalPhysicalMemory / 1MB );
                            'Organization' = $WMI_CS.Organization; 
                         'OperatingSystem' = $WMI_OS.Caption;
                             'ServicePack' = $WMI_OS.CSDVersion;
                          'OSArchitecture' = $WMI_OS.OSArchitecture;
                              'OSLanguage' = (ConvertTo-JDOSLanguage -Digit $WMI_OS.OSLanguage)
                             'BuildNumber' = $WMI_OS.BuildNumber;
                            'SerialNumber' = $WMI_OS.SerialNumber;
                                 'Version' = $WMI_OS.Version;
                          'LastBootUpTime' = $WMI_OS.ConvertToDateTime($WMI_OS.LastBootUpTime)|Get-Date -UFormat "%Y-%m-%d %R";
                               'Collected' = Get-Date -UFormat "%Y-%m-%d %R";
                           'ProcessorName' = $WMI_PR.Name
                           'NumberOfCores' = $WMI_PR.NumberOfCores

                    }
                    #$OutputEncoding = [system.text.encoding]::UTF8

                    $obj = New-Object -TypeName PsObject -Property $props 
                    $obj.psobject.typenames.insert(0,'Report.ComputerSystem')
                    Write-Output $obj
                }
            }
        }
    }
}

function Get-JDInstalledApps
{
#.ExternalHelp JDInventory.Help.xml
    [CmdletBinding()]
    Param
    (
		[Parameter(Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("CN","Computer","IpAdress")]
        [string[]]$ComputerName = 'localhost' ,

        [System.Management.Automation.PSCredential]$Credential
	)
    PROCESS 
    {
        foreach ($Computer in $ComputerName)
        {
            if (checkComputerConnection $Computer)
            {
                try
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $WMI_SOFT = Get-WmiObject Win32_Product -ComputerName $Computer -ErrorAction Stop
                    }
                    elseif($PSBoundParameters['Credential']){
                        $WMI_SOFT = Get-WmiObject Win32_Product -ComputerName $Computer -Credential $Credential -ErrorAction Stop
                    }
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Warning "$($messages.Warning_Access) $Computer."
                }
                finally
                {
                    if( -not $PSBoundParameters['Credential'] )
                    {
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer).ComputerName
                    }
                    elseif ( $PSBoundParameters['Credential'] )
                    { 
                        $CompName = (Get-JDComputerInfo -ComputerName $Computer -Credential $Credential).ComputerName
                    }
                
                    foreach ($Product in $WMI_SOFT)
                    {
                        $props = @{'ComputerName' = $CompName
                                         'Caption' = $Product.Caption
                                            'Name' = $Product.Name
                                         'Version' = $Product.Version
                                          'Vendor' = $Product.Vendor
                               'IdentifyingNumber' = $Product.IdentifyingNumber
                                       'Collected' = Get-Date -UFormat "%Y-%m-%d %R"
                        }
                        $obj = New-Object -TypeName PsObject -Property $props
                        $obj.psobject.typenames.insert(0,'Report.SoftWare')
                        Write-Output $obj
                    }
                }
            }
        }
    }
}

function ConvertTo-JDOSLanguage
{
#.ExternalHelp JDInventory.Help.xml
    [CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=$true)]
        [int]$Digit,

        [switch]$hexadecimal
	)
    if ($hexadecimal)
    {
        $Digit = [System.Convert]::ToInt32("$Digit",16)
    }
    
    switch ($Digit)
    {
        1 {$Output = 'Arabic'}
        4 {$Output = 'Chinese (Simplified)– China'}
        9 {$Output = 'English'}
        1025 {$Output = 'Arabic – Saudi Arabia'}
        1026 {$Output = 'Bulgarian'}
        1027 {$Output = 'Catalan'}
        1028 {$Output = 'Chinese (Traditional) – Taiwan'}
        1029 {$Output = 'Czech'}
        1030 {$Output = 'Danish'}
        1031 {$Output = 'German – Germany'}
        1032 {$Output = 'Greek'}
        1033 {$Output = 'English – United States'}
        1034 {$Output = 'Spanish – Traditional Sort'}
        1035 {$Output = 'Finnish'}
        1036 {$Output = 'French – France'}
        1037 {$Output = 'Hebrew'}
        1038 {$Output = 'Hungarian'}
        1039 {$Output = 'Icelandic'}
        1040 {$Output = 'Italian – Italy'}
        1041 {$Output = 'Japanese'}
        1042 {$Output = 'Korean'}
        1043 {$Output = 'Dutch – Netherlands'}
        1044 {$Output = 'Norwegian – Bokmal'}
        1045 {$Output = 'Polish'}
        1046 {$Output = 'Portuguese – Brazil'}
        1047 {$Output = 'Rhaeto-Romanic'}
        1048 {$Output = 'Romanian'}
        1049 {$Output = 'Russian'}
        1050 {$Output = 'Croatian'}
        1051 {$Output = 'Slovak'}
        1052 {$Output = 'Albanian'}
        1053 {$Output = 'Swedish'}
        1054 {$Output = 'Thai'}
        1055 {$Output = 'Turkish'}
        1056 {$Output = 'Urdu'}
        1057 {$Output = 'Indonesian'}
        1058 {$Output = 'Ukrainian'}
        1059 {$Output = 'Belarusian'}
        1060 {$Output = 'Slovenian'}
        1061 {$Output = 'Estonian'}
        1062 {$Output = 'Latvian'}
        1063 {$Output = 'Lithuanian'}
        1065 {$Output = 'Persian'}
        1066 {$Output = 'Vietnamese'}
        1069 {$Output = 'Basque (Basque)'}
        1070 {$Output = 'Serbian'}
        1071 {$Output = 'Macedonian (Macedonia (FYROM))'}
        1072 {$Output = 'Sutu'}
        1073 {$Output = 'Tsonga'}
        1074 {$Output = 'Tswana'}
        1076 {$Output = 'Xhosa'}
        1077 {$Output = 'Zulu'}
        1078 {$Output = 'Afrikaans'}
        1080 {$Output = 'Faeroese'}
        1081 {$Output = 'Hindi'}
        1082 {$Output = 'Maltese'}
        1084 {$Output = 'Scottish Gaelic (United Kingdom)'}
        1085 {$Output = 'Yiddish'}
        1086 {$Output = 'Malay – Malaysia'}
        2049 {$Output = 'Arabic – Iraq'}
        2052 {$Output = 'Chinese (Simplified) – PRC'}
        2055 {$Output = 'German – Switzerland'}
        2057 {$Output = 'English – United Kingdom'}
        2058 {$Output = 'Spanish – Mexico'}
        2060 {$Output = 'French – Belgium'}
        2064 {$Output = 'Italian – Switzerland'}
        2067 {$Output = 'Dutch – Belgium'}
        2068 {$Output = 'Norwegian – Nynorsk'}
        2070 {$Output = 'Portuguese – Portugal'}
        2072 {$Output = 'Romanian – Moldova'}
        2073 {$Output = 'Russian – Moldova'}
        2074 {$Output = 'Serbian – Latin'}
        2077 {$Output = 'Swedish – Finland'}
        3073 {$Output = 'Arabic – Egypt'}
        3076 {$Output = 'Chinese (Traditional) – Hong Kong SAR'}
        3079 {$Output = 'German – Austria'}
        3081 {$Output = 'English – Australia'}
        3082 {$Output = 'Spanish – International Sort'}
        3084 {$Output = 'French – Canada'}
        3098 {$Output = 'Serbian – Cyrillic'}
        4097 {$Output = 'Arabic – Libya'}
        4100 {$Output = 'Chinese (Simplified) – Singapore'}
        4103 {$Output = 'German – Luxembourg'}
        4105 {$Output = 'English – Canada'}
        4106 {$Output = 'Spanish – Guatemala'}
        4108 {$Output = 'French – Switzerland'}
        5121 {$Output = 'Arabic – Algeria'}
        5127 {$Output = 'German – Liechtenstein'}
        5129 {$Output = 'English – New Zealand'}
        5130 {$Output = 'Spanish – Costa Rica'}
        5132 {$Output = 'French – Luxembourg'}
        6145 {$Output = 'Arabic – Morocco'}
        6153 {$Output = 'English – Ireland'}
        6154 {$Output = 'Spanish – Panama'}
        7169 {$Output = 'Arabic – Tunisia'}
        7177 {$Output = 'English – South Africa'}
        7178 {$Output = 'Spanish – Dominican Republic'}
        8193 {$Output = 'Arabic – Oman'}
        8201 {$Output = 'English – Jamaica'}
        8202 {$Output = 'Spanish – Venezuela'}
        9217 {$Output = 'Arabic – Yemen'}
        9226 {$Output = 'Spanish – Colombia'}
        10241 {$Output = 'Arabic – Syria'}
        10249 {$Output = 'English – Belize'}
        10250 {$Output = 'Spanish – Peru'}
        11265 {$Output = 'Arabic – Jordan'}
        11273 {$Output = 'English – Trinidad'}
        11274 {$Output = 'Spanish – Argentina'}
        12289 {$Output = 'Arabic – Lebanon'}
        12298 {$Output = 'Spanish – Ecuador'}
        13313 {$Output = 'Arabic – Kuwait'}
        13322 {$Output = 'Spanish – Chile'}
        14337 {$Output = 'Arabic – U.A.E.'}
        14346 {$Output = 'Spanish – Uruguay'}
        15361 {$Output = 'Arabic – Bahrain'}
        15370 {$Output = 'Spanish – Paraguay'}
        16385 {$Output = 'Arabic – Qatar'}
        16394 {$Output = 'Spanish – Bolivia'}
        17418 {$Output = 'Spanish – El Salvador'}
        18442 {$Output = 'Spanish – Honduras'}
        19466 {$Output = 'Spanish – Nicaragua'}
        20490 {$Output = 'Spanish – Puerto Rico'}
        Default {Write-Warning " Unknown language code"}
    }
    Write-Output $Output
}

function checkComputerConnection
{
    [CmdletBinding()]
	param([string]$Computer)
    $works = $true
    Write-Verbose "$($messages.Verbose_UseComputer) $Computer"
    Write-Verbose "$($messages.Verbose_TestConnection) $Computer"
    if (Test-Connection -ComputerName $Computer -Count 2 -Quiet)
    {
        try
        {
            Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -ErrorAction Stop | Out-Null
            Write-Verbose "$($messages.Verbose_ConnectionSuccess) $Computer"
        }
        catch
        {
            $works=$false
            Write-Warning "$($messages.Warning_Connection) $Computer"
        }
    }
    else
    {
       $works=$false
       Write-Warning "$($messages.Warning_Connection) $Computer"
    }
    return $works
}

Export-ModuleMember -Function Get-JDDiskDrive,Get-JDNetworkAdapter,Get-JDComputerInfo,Get-JDInstalledApps,ConvertTo-JDOSLanguage