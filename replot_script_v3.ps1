#Set-ExecutionPolicy RemoteSigned
Clear-Host
Write-Host "**** Mad Max Chia Replotter **** `n"
if ((Test-Path chia_plot.exe) -eq $false){
    Write-Host "**** Mad Max Program, chia_plot.exe, was not found you must run this script from the same directory. ****"
    exit
}

#*********** SET THIS DATA! ***********#
#set data#
$temp_path = ""
$dest_path = ""

#set keys
$farmer_key = ""
$contract_address = ""

#email settings
$Email_To = ""
$Email_From = ""
$Email_Pass = ""
$SMTPServer = ""
$SMTPPort = 0


#set if we want to replot or not
$replot_og = "true"

#settings
##these will be auto if not set here
$number_of_plots="" #based on disk size
$threads="" #based on processor info


#*********** END SET THIS DATA! ***********#

##rest Vars
$plot_times  =  @()

#first time will be the start datetime
$plot_times += ((Get-Date))
$start_time = $plot_times[0];
Write-Host "**** Start: $start_time ****"

#logging
if ((Test-Path logs) -eq $false){
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
$logname = "logs/log_" + $plot_times[0].ToString("yyyyMMddhhmmss")+".txt"
Start-Transcript -path $logname | Out-Null

## Functions ##

function send_email {
    param ( $Email_To, $Email_From,  $Email_Pass,  $SMTPServer,  $SMTPPort)
    
    $Subject ="Plotting on $env:computername" 
    $Body = "Plotting Completed"
    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($Email_From, $Email_Pass);
    $SMTPClient.Send($Email_From, $Email_To, $Subject, $Body)
}


function clear_temp{
  Param ($temp_path)
    Get-ChildItem $temp_path | Where-Object {$_.Extension -eq ".tmp"} | ForEach-Object { $_.Delete()}
    write-host "**** Cleared $temp_path ****"
}

function check_how_many_replace{
    Param ($dest_path)

     $pool_release_date = [datetime]::ParseExact("2021-07-07", "yyyy-MM-dd", $null) 
     #list of files in order from the oldest to newest to remove with full file name
     $file_list =  @()
     $file_list = Get-ChildItem $dest_path | Where-Object { $_.CreationTime -lt $pool_release_date} | Sort-Object $_.CreationTime 
     return $file_list

}

function delete_old_plot{
  Param ($file)
        Remove-Item $file
        write-host "**** Deleted $file ****"
    }

## End Functions ##

##### Program ####
if ($dest_path -eq ""){ 
Write-Host "Destination Path not set"
exit
}

if ($temp_path -eq ""){ 
Write-Host "Temp Path not set"
exit
}


if ((Test-Path $dest_path) -eq $false){
    Write-Host "Destination Path not found"
    exit
}


if ((Test-Path $temp_path) -eq $false){
    Write-Host "Temp Path not found"
    exit
}

if (($farmer_key -eq "") -or ($contract_address -eq "" )){ 
Write-Host "Keys not set"
exit
}

if ($replot_og -eq ""){ 
Write-Host "How would you like your plots? Replot not set"
exit
}

#fixing paths
if ($dest_path -notmatch '\\$'){
    $dest_path += '\'
}

if ($temp_path -notmatch '\\$'){
    $temp_path += '\'
}


#getting the max number of plots possible
$letter = $dest_path[0]
$max_size_bytes =(Get-WmiObject win32_logicaldisk -Filter "DeviceID='$letter`:'" | Select-Object -ExpandProperty Size)
$max_size_in_gb = [math]::floor($max_size_bytes/1073741824)
$max_plots = [math]::floor($max_size_in_gb/101.4)


$free_size_bytes =(Get-WmiObject win32_logicaldisk -Filter "DeviceID='$letter`:'" | Select-Object -ExpandProperty FreeSpace)
$free_size_in_gb = [math]::floor($free_size_bytes/1073741824)
$free_plots = [math]::floor($free_size_in_gb/101.4)
write-host "**** Max Plots possible on this drive: $max_plots ****"
write-host "**** Free Plots possible on this drive: $free_plots ****"

$cpu_threads= (Get-WmiObject -Class Win32_Processor | Select-Object  -ExpandProperty NumberOfLogicalProcessors)

if ($threads -eq ""){ 
    $threads = ($cpu_threads - 2)
    Write-Host "**** Setting max threads to $threads ****"

   if ($threads -eq 0){ 
        Write-Host "Nope not doing it. I don't have enough threads, I need at least 4."
        exit

   }
    
}


##clear temp path of .tmp files
clear_temp $temp_path
$loop_counter = 1

if ($replot_og -eq "true"){
Write-Host "**** Replotting OG Plots in $dest_path ****"
   
   $file_list = check_how_many_replace($dest_path)
   $file_list_count = $file_list.Count
 
    if($file_list_count -eq 0){

       if($free_plots -eq 0){
         Write-Host "**** Not enough space in $dest_path Exiting **** "
         exit
       }

        Write-Host "**** Just making new Plots in $dest_path **** "
        if ($number_of_plots -eq ""){ 
            $number_of_plots = $free_plots
        }
            do {
                Write-Host "**** Making $loop_counter / $number_of_plots ****"
                .\chia_plot.exe -n 1 -r $threads -u 256 -t $temp_path -d $dest_path -c $contract_address -f $farmer_key
                $plot_times += ((Get-Date))
                $loop_counter++
            } while($loop_counter -le $number_of_plots)

     
    }else{
        $number_of_plots = $file_list_count

        Write-Host "**** $number_of_plots OG Plots in $dest_path will be replaced ****"
    do {
        $index = ($loop_counter - 1)
        $old_plot = $file_list[$index]
        $file_path = $dest_path+$old_plot
        delete_old_plot($file_path)
        Write-Host "**** Making $loop_counter / $number_of_plots ****"
       .\chia_plot.exe -n 1 -r $threads -u 256 -t $temp_path -d $dest_path -c $contract_address -f $farmer_key
       $plot_times += ((Get-Date))
       $loop_counter++
    } while($loop_counter -le $number_of_plots)
    
    }#end number of plots check

}

if ($replot_og -eq "false"){
Write-Host "**** Just making new Plots in $dest_path **** "
#if number of plots if we just using freespace
    if ($number_of_plots -eq ""){ 
        $number_of_plots = $free_plots
    }
    if ($number_of_plots -eq 0){
        Write-Host "Not enough space to make a new plot. Exiting...."
        exit
    }
    do {
        Write-Host "**** Making $loop_counter / $number_of_plots ****"
        .\chia_plot.exe -n 1 -r $threads -u 256 -t $temp_path -d $dest_path -c $contract_address -f $farmer_key
        $plot_times += ((Get-Date))
        $loop_counter++
    } while($loop_counter -le $number_of_plots)

}#end replot check # end new plots maker


Write-Host "**** Complete ****"
$time_taken = New-TimeSpan -Start $plot_times[0] -End $plot_times[-1]

Write-Host "**** Time Taken: $time_taken. ****"
Stop-Transcript

if ($Email_To -ne ""){
    send_email -Email_To $Email_To -Email_From $Email_From -Email_Pass $Email_Pass -SMTPServer $SMTPServer -SMTPPort $SMTPPort
}
