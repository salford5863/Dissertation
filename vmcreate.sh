#!/bin/bash
#
# vmcreate - This Tool help to setup Lab Environment very instantaneously. We can spin
#			 N no machine according to our requirment and the base machine hardware
#			 configuration's. we can also list and delete machine using this tool.
#           Written using Shell Script.

# USAGE: ./vmcreate
#
# REQUIREMENTS: Vagrant and Virtual Box
#
# OVERHEAD: Only when this tool is deployed for the first time it will download
#           a centos7 800MB Size image from Vagrant Cloud, thereafter for every new spin
#			the image already downloaded and available in the cache will be deployed.


##############################################################
#           Global Variable                                  #
##############################################################
Local_Box_Path="/usr/local/mydbops/centos7.box"
#Local_Box_Path="/Users/Lalit kumar/Documents/works/package.box"
Box_Name="geerlingguy/centos7"
#Box_Name="hashicorp/precise64"
Numeric='^[0-9]+$'
Default_VagFile=${HOME}/Vagrantfile
maxMemory=$(free -m |sed -n 2p|awk {'print $2'})
availableMaxMemory=$(($maxMemory-1024))
minMemory=512
totalCPUs=$(nproc)
availableCPUs=$[totalCPUs-1]
availableDisk=$(df -h | sed -n 2p |awk {'print $4'}|sed 's/.$//')
diskDirectory=${HOME}/.Vmdisk/
hostnamePrefix=mydbopslabs
basecommand="$(basename $0|cut -d'.' -f1)"





#This function evaluate all command here
#If the command fail, its automatically exists
function Warn()
{
	if ! eval "$@"; then
		echo  >&2 "WARNImydbopslabs11led \"$@\""
		exit
	fi
}



#change ram to mb
function changeRAMtoMB() 
 { 
  
  
    suff=`expr "echo $RAM"| grep -o '.$'`    
    pref=`expr $RAM | sed 's/.$//'`  
    if [ "$suff" == g ] || [ "$suff" == G ]  
    then  
    RAM=$(($pref*1024))  
    elif [[ $suff = m || $suff = M ]] 
    then 
    RAM=$pref   
    fi 
  
 } 


# providing default valumydbopslabs11

function defaultValues()
 
{
#CPU operation
    if [ -z "$CPU" ]
    then
    CPU=1
	elif [ "$CPU" -gt "$availableCPUs" ]
	then
	echo "machine have only $availableCPUs cpu please give under this"
	exit
	fi	   
#RAM operation	
	if [ -z "$RAM" ] 
	then
	RAM=512m
	fi     
	changeRAMtoMB
	if [[ -z "$RAM" || "$RAM" -lt "$minMemory" ]]
    then
    RAM=512
   elif [ "$RAM" -gt "$availableMaxMemory" ]
   then
   echo "machine have only $availableMaxMemory.MB or 6.53GB memory please give under this"
   exit
   fi
}




#This Function use to spin new vms according to the user input.
#This Function will check for a Vagarantfile under Default_VagFile variable location
#If it exists Update_Existing_Vagrant_Env will be call
#If its not existsUpdate_Existing_Vagrant_Env will be call
function Creating_NewMachine()
{

	[ -f ${Default_VagFile} ] && Update_Existing_Vagrant_Env || Create_New_Vagrant_Env
}


#This Function help to add vagrant box to local cache
#This function will call by Create_New_Vagrant_Env and Update_Existing_Vagrant_Env
function Chk_And_Add_VBox_To_LCache()
{
	#checking local vagrant cache
	if vagrant box list | grep -i ${Box_Name}  > /dev/null
	then
		echo " " > /dev/null
	else
		echo "Requested ${Box_Name} not existed on your local vagrant cache, so we are downloading for you. Please hold with us."
		Warn "vagrant box add ${Box_Name} ${Local_Box_Path}" > /dev/null

		#After adding the box to our local cache checing its poperly added and printing the status to the user
		if vagrant box list | grep -i ${Box_Name}  > /dev/null
		then
			echo "${Box_Name} successfully added to you local cache"
		else
			echo "There's some issue in adding ${Box_Name} vagrant box to your local cache"
			exit 1
		fi
	fi
}


#This function help to create new vagrant env
#Once VMS created, all machine will be powered On
function Create_New_Vagrant_Env()
{
	starting_ip_oct=10

	#Calling Chk_And_Add_VBox_to_LCache function to check vagrant box exists on local cache. If not this function will try to add.
	Chk_And_Add_VBox_To_LCache


	cat  >> ${Default_VagFile} <<EOL
	Vagrant.configure("2") do |config|
EOL
	for (( i=1; i <= $no_machine; i++))
	do
     
     	ip=`expr $i + $starting_ip_oct`
	hostname="mydbopslabs$ip"
			    
	         defaultValues
 
 		cat  >> ${Default_VagFile} <<EOL
	        config.vm.define "$hostname" do |$hostname|
		            ${hostname}.vm.synced_folder "${HOME}", "/vagrant", type: "virtualbox"
	                ${hostname}.vm.box = "${Box_Name}"
                    ${hostname}.vm.network "private_network", ip: "192.168.33.${ip}"
		            ${hostname}.vm.hostname = "$hostname"
                    $hostname.vm.provider :virtualbox do |$hostname|
                    	$hostname.customize ["modifyvm", :id, "--memory", "$RAM"] 
                    	$hostname.customize ["modifyvm", :id, "--cpus", "$CPU"] 
		            end  
            end

EOL
echo -e "$hostname is created\n$hostname have $RAM.mb memory and $CPU cpu"

	done
	cat >> ${Default_VagFile} <<EOL
	end
EOL

	diskAllocate
	#Calling Power on machine function, to start the machine
	#PowerOn_Individual_Machines
	#Installing vagrant-vbguest plugin, It will check and update the VirtualBox guest additions every time you run a vagrant up command
	#Warn "vagrant plugin install vagrant-vbguest"
	List_UPVMS
	echo "You can login to the Vagrant Box using command \"vagrant ssh [name|id]\""
}


#This function help to add new VMS to existing Vagrant Infra
function Update_Existing_Vagrant_Env()
{
	starting_ip_oct=$(grep -io mydbopslabs[0-9][0-9] ${Default_VagFile} | sort -u | tr -dc '0-9' | tail -c 2)

	while true
	do
		#read -p "Enter no of machine to spin: " no_machine
		if [[ $no_machine =~ ${Numeric} ]];
		then
			break
		else
			echo "You have entered Non-Numberic value."
			echo "Please try again."
			echo "If you need to exit, please press CTRL+C."
		fi


	done

	#MAC OSX "This sed comman use to delete last on the below specified file $ represent lastline d represent delete command"
	if [ $(uname) != "Linux" ]
	then
		sed -i '' '$d' ${Default_VagFile}
	else
	#Linux "This sed comman use to delete last on the below specified file $ represent lastline d represent delete command"
		sed -i '$d' ${Default_VagFile}
	fi

    for (( i=1; i <= $no_machine; i++))
    do
         
	
         ip=`expr $i + $starting_ip_oct` 
       hostname="mydbopslabs$ip"
            
			
			 defaultValues


 		cat  >> ${Default_VagFile} <<EOL
            config.vm.define "$hostname" do |$hostname|
					${hostname}.vm.synced_folder "${HOME}", "/vagrant", type: "virtualbox"
					${hostname}.vm.box = "${Box_Name}"
					${hostname}.vm.network "private_network", ip: "192.168.33.${ip}"
					${hostname}.vm.hostname = "$hostname"
					$hostname.vm.provider :virtualbox do |$hostname|
                    $hostname.customize ["modifyvm", :id, "--memory", "$RAM"] 
                    $hostname.customize ["modifyvm", :id, "--cpus", "$CPU"] 
	                end  
            end
EOL
    echo -e "$hostname is created\n$hostname have $RAM.mb memory and $CPU cpu"
    done
    cat >> ${Default_VagFile} <<EOL
    end
EOL
    
	diskAllocate
	#Calling Chk_And_Add_VBox_to_LCache function to check vagrant box exists on local cache. If not this function will try to add.
	Chk_And_Add_VBox_To_LCache
	#Calling Power on machine function, to start the machine
	#PowerOn_Individual_Machines
	#Installing vagrant-vbguest plugin, It will check and update the VirtualBox guest additions every time you run a vagrant up command
	#Warn "vagrant plugin install vagrant-vbguest"
	List_UPVMS
	echo "You can login to the Vagrant Box using command \"vagrant ssh [name|id]\""
}


#This Function help to select option on Deleting VMS
#If user select YES, Delete_All_Machine function will be call
#If user select NO, Deleting_Individual_VMS function will be called
function Deleting_VMS()
{
	List_UPVMS
	listvmreturn=$?
	if [ $listvmreturn == 0 ]
	then
		while true
    	do
        	#read -p "Please select y(Yes) to Delete the Particular VMS or N(No) to delete all VMS:" ans
        	if [[ -z "${ans}" ]];
        	then
            	echo "You didnt enter anything."
            	echo "Please try again."
            	echo "If you need to exit, please press CTRL+C."
        	else
            	break
        	fi
		done

		case ${ans} in		
			"n" | "no" | "N" | "NO" | "No" |"nO" ) Delete_All_Machine
			;;
		esac
	fi
}



#This function help to Delete all VMS
#This function will remove Vagrantfile
#This function calling from Deleting_VMS
function Delete_All_Machine()
{
	machineName=$(vagrant status 2> /dev/null|grep mydbopslabs|awk {'print $1'})
	
	if [ -z "$machineName" ]
	then
			echo "there is no vm to delete"
			exit
	fi	
	
	for arg in $machineName
	do 
		
    	machine=$arg
		deleteMachine
	done 
	
	Warn "rm -rf ${Default_VagFile}"
	echo "All Vagrant machines are deleted and Vagrantfile was removed"
	exit
}


#This function use to list VMS on the Vagrant Env
#This function calling from many places of this program
#It will store the output on lsvmout variable
function List_UPVMS()
{
	lsvmout=$(Warn "vagrant status" | grep -v 'This\|The'| tee /dev/tty)
	grep -q "running" <<< $lsvmout
	if [ $? == 0 ]
	then
		return 0
	else
		echo "Check your Vagrantfile for more details"
	fi
}

#delete all machine with disk
function Delete_All_Machine_with_disk()
{
	val=$(vagrant status 2> /dev/null|grep mydbopslabs)
	if [ -z "$val" ]
	then
		echo -e "there is no vm to delete\nto create vm 'vmcreate new'"
		exit
	fi

	Warn "vagrant destroy -f" 2> /dev/null
	Warn "rm -rf ${Default_VagFile}"
	echo "All Vagrant machines are deleted and Vagrantfile was removed"
	echo "to create vm 'createvm new'"
}


#This Function help to select option on Halt VMS
#If user select YES, all VMS Halt in this function itself
#If user select NO Halt_Individual_Machines function will be called
function Halt_Vms()
{
	List_UPVMS
	listvmreturn=$?
	if [ $listvmreturn == 0 ]
	then
		while true
    	do
        	#read -p "Are you Planning to Halt all VMS, Please Press Y/n: " uchoice
        	if [[ -z "${uchoice}" ]];
        	then
            	echo "You didnt enter anything."
            	echo "Please try again."
            	echo "If you need to exit, please press CTRL+C."
        	else
            	break
        	fi
    	done

		case ${uchoice} in
		       "Y" | "Yes"| "yes" | "y") Warn "vagrant halt -f"
				;;
		esac
	fi
	echo "All systems are shutdown"
}


#This function help to Halt more then one VMS
#This function calling from Halt_Vms
function Halt_Individual_Machines()
{
	while true
   do
        #read -p "Please enter the machine name to Halt (you can specify mutiple machine by using space):" -a mname
        if [[ -z "${mname}" ]];
        then
           echo "You didnt enter anything."
           echo "Please try again."
           echo "If you need to exit, please press CTRL+C."
       else
           break
       fi
	done

	for i in ${mname[@]}
	do
		Warn "vagrant halt ${i}"
	done
	echo "$mname was shutdown"
	
	if [ -z "$manme" ]
	then
	 	exit
	fi
}


#This Function help to select option on Power On VMS
#If user select YES, all VMS Power On in this function itself
#If user select NO PowerOn_Individual_Machines function will be called
function PowerOn_Machines()
{
	List_UPVMS
	listvmreturn=$?
	if [ $listvmreturn == 0 ]
	then
		while true
    	do
        	#read -p "If your planning to PowerOn all VMS press Yes/y or Need to PowerOn more then One VMS press No/n: " uchoice
        	if [[ -z "${uchoice}" ]];
        	then
            	echo "You didnt enter anything."
            	echo "Please try again."
            	echo "If you need to exit, please press CTRL+C."
        	else
            	break
        	fi
    	done

		case ${uchoice} in
		       "Y" | "Yes"| "yes" | "y") Warn "vagrant up"
				;;
		esac
	fi
	echo -e "all machines are power on\nto start vm '$basecommand start -n <machine>'"
}


#This function help to Power On more then one VMS
#This function calling from PowerOn_Machines
function PowerOn_Individual_Machines()
{
	

	for i in ${mname[@]}
	do
		Warn "vagrant up ${i}"
		echo -e "\n$mname is started\nto login vm '$basecommand ssh <machine>'"
	done
	
	if [ -z "$mname" ]
	then
		exit
	fi
}


#This Function help to select option on restarting VMS
#If user select YES all VMS reload in this function itself
#If user select NO Reload_Individual_Machines function will be called
function Restart_Machines()
{
	List_UPVMS
	listvmreturn=$?
	if [ $listvmreturn == 0 ]
	then

		while true
    	do
        	#read -p "If your planning to Restart all VMS press Yes/y or Need to Restart more then One VMS press No/n : " uchoice
        	if [[ -z "${uchoice}" ]];
        	then
            	echo "You didnt enter anything."
            	echo "Please try again."
            	echo "If you need to exit, please press CTRL+C."
        	else
            	break
        	fi
    	done

		case ${uchoice} in
		       "Y" | "Yes"| "yes" | "y") Warn "vagrant reload"
				;;
		esac
	fi
	echo "all machines was restarted"

}


#This function help to reload more then one VMS
#This function calling from Restart_Machines
function Reload_Individual_Machines()
{


	for i in ${mname[@]}
		 do
		Warn "vagrant reload ${i}"
	done
}


#This function help to exit out of the program
function Exit_Script()
{
	exit 0
}






#attaching disk

function diskAttach()
{
	if [ -z "$machine" ]
	then
		echo -e "please enter machine name\n$basecommand disk attach -n <machine> -d <disk> -v <volume>"
		exit
	fi
	
	num=$(grep -i $xdisk $Default_VagFile)
	check=$(ls $diskDirectory| grep $xdisk)
	checkMachine=$(grep -o $machine $Default_VagFile| head -n 2)
#checking machine is present in which disk is to be attach.
	
	if [ -z "$checkMachine" ]
	then
		echo -e "no machine is configured with this name please check machine list\n\"$basecommand list -a\""
		exit
	fi

# checking for pre-configured disk
	if [ ! -z "$num" ]
	then
		echo "this disk is already attached to other machine"
	exit
	fi	
	if [ ! -z "$xdisk" ]
	then
		disklists=$(ls ${diskDirectory} | grep $xdisk)
		if [[ ! -z "$disklists" && ! -z "$diskVolumeSize" ]]   
		then
			echo -e "$xdisk is pre-configured it cannot accept volume\nplease use $basecommand update -n <machine> -d <disk> -v < volume>"
			exit
		fi  
	fi 
 
#checking machine have attached disk or not
	val=$(grep -n $machine $Default_VagFile| grep storageattach | cut -d: -f1)
	if [ ! -z "$val" ]
	then
		echo -e "system already have attached disk"
		exit
#checking disk is created or not

	elif [ -z "$check"  ] 
	then
		if [ -z "$diskVolumeSize" ]
		then
			diskVolumeSize=1024
		fi
		val=$(grep -n $machine $Default_VagFile| grep provider | cut -d: -f1)
		val=$(($val+1))
		sed -i "${val}i \                   \ unless File.exist?('/home/ladmin/.Vmdisk/$xdisk')" $Default_VagFile
		val=$(($val+1))
		sed -i "${val}i \                       \ $machine.customize ['createhd', '--filename','/home/ladmin/.Vmdisk/$xdisk', '--variant', 'Standard', '--size', $diskVolumeSize]" $Default_VagFile
		val=$(($val+1))    
		sed -i "${val}i \                   \ end" $Default_VagFile
		val=$(($val+1))    
		sed -i "${val}i \                       \ $machine.customize ['storageattach', :id,  \'--storagectl', 'IDE Controller', \'--port', 1, \'--device', 0, \'--type', 'hdd', \'--medium','/home/ladmin/.Vmdisk/$xdisk']" $Default_VagFile
		echo -e "$xdisk of volume $diskVolumeSize.MB is attached to $machine machine\nto start '$basecommand start -n <machine>'"
		exit
	#checking disk attached to any system or not
	elif [ ! -z "$num" ]
	then
		echo "this disk is already attached to other machine"
		else
		val=$(grep -n $machine $Default_VagFile| grep provider | cut -d: -f1)
		val=$(($val+1))    
		sed -i "${val}i \                       \ $machine.customize ['storageattach', :id,  \'--storagectl', 'IDE Controller', \'--port', 1, \'--device', 0, \'--type', 'hdd', \'--medium','/home/ladmin/.Vmdisk/$xdisk']" $Default_VagFile
		echo "$xdisk is attached to $machine machine"
	    
	fi  
	exit

}



# machine name Validation
function machineNameValidation()
{
	checkMachineExistance=$(vagrant status|grep mydbops)
	if [ -z "$checkMachineExistance" ]
	then
		echo -e "there is no machine present\nto create vm '$basecommand new'"
		exit
	fi
	

	if [ ! -z "$mname" ]
	then
		validateName=$mname
	elif [ ! -z "$machine" ]
	then
		validateName=$machine
	fi

	if [ -z "$validateName" ]
	then
		exit
	fi
	
	machineNmame=$(vagrant status|grep -wo $validateName)
	if [ "$machineNmame" != "$validateName" ]
	then
		echo -e "incorrect machine name\nor machine is not configured"
		exit
	fi







}



#function to delete disk
function deleteSecondaryDisk()
{
	check=$(ls $diskDirectory| grep -w $xdisk)
	if [ -z "$check" ]
	then
		echo " there is no disk with this name"
		exit
	fi

	val=$(ls ~|grep Vagrantfile)
	if [ ! -z "$val" ]
	then
		val=$(grep $xdisk $Default_VagFile | grep storageattach)
		if [ ! -z "$val" ]
		then
			echo "$xdisk disk is attached to some machine please remove first"
			exit
		fi
	fi
	
	val=$(VBoxManage list hdds | grep -B 4 $xdisk | head -n 1|cut -d: -f2) 
	vboxmanage closemedium disk $val --delete
	echo "$xdisk disk was deleted"
	
	exit
}







#Function To Display Menus
function showMenu()

{

clear

echo -e "  new                          [ for creating new virtual machine ]
                               [ -c|--cpu < number of cpu(s) > < default value is 1 >]
                               [ -m|--memory < diskVolumeSize > < default value is 512M >]
			       [ -d|--disk < diskVolumeSize > ]
			       [ -v|--volume < assign required volume to secondary disk]"
echo -e "\n"
echo " update                        [ for update existing virtual mahine ]\n
                               [ -c|--cpu < number of cpu(s) > ]\n
                               [ -m|--memory < diskVolumeSize > ]\n
                               [ -d|--disk < diskVolumeSize > ]"
echo -e "\n"
echo " delete                        [ to delete virtual machine ]\n
                               [ -a|--all     < to delete all machine >]\n
                               [ -n|--name     < to delete particular virtual machine > ]"
echo -e "\n"
echo " list                          [ list of machine(s) ]\n
                               [ -a|--all < print list of all machine > ]\n
                               [ -r|--running < print only running machines > ]"                 
echo -e "\n"
echo " restart                       [ -a|--all      < restart all machines > ]\n
                               [ -n|--name     < for particular machine > ]"
echo -e "\n"
echo " start                         [ -a|--all      < start all machines > ]\n
                               [ -n|--name     <for particular machine > ]"
echo -e "\n" 
echo " info                          [ -n|--name    < show secondary storage information > ]\n
                               [ -a|--all < show all secondary disk details > ]\n
                               [ -f|--find < show where disk is attached > ]\n
                               [ -l|--list < list of secondary disk > ]"
echo -e "\n"
echo " deattach                      [ name   < de-attach secondary disk from machine > ]\n
                               [ -n|--name   < deattach secondary disk from machine > ]"
echo -e "\n" 
echo " exit                          [ exit ]"
echo -e "\n"

}




############################################################################################################################
#                                      Script Start Here                                                                   #
############################################################################################################################
	
type -P vagrant &> /dev/null && echo "Found" >> /dev/null || if [ "$(id -u)" != "0" ]; then

 eval "$(echo "
#Vagrant Not installed on your machine, kindly follow the below step to install the same.

# Some notes from installing VirtualBox on CentOS 7.
# These exact steps haven't been tested, as I ran them in a different order when manually installing.

# Install dependencies
yum -y install gcc make patch  dkms qt libgomp
yum -y install kernel-headers kernel-devel fontforge binutils glibc-headers glibc-devel

# Install VirtualBox
cd /etc/yum.repos.d
wget http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo
yum -y install VirtualBox-5.0

# Check that you have the kernel sources downloaded for your running kernel version (if they don't match you might need to yum update and reboot)
ls /usr/src/kernels/
uname -r

# Build the VirtualBox kernel module
export KERN_DIR=/usr/src/kernels/$(uname -r)
/sbin/rcvboxdrv setup

# Install Vagrant
yum -y install https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.rpm
")"
else
	echo "Vagrant not installed on this machine, Installion only done by root user, so please execute this script as root or kindly check with your System Team"
	exit 1
fi


#Trap CTRL+C, CTRL+Z and quit singles
#trap '' SIGINT SIGQUIT SIGTSTP

##########################################################################
#Creating Vagrant Home DIR on /tmp and exporting Custom Vagrant variable #
##########################################################################
[ -d /tmp/$USER ] || mkdir /tmp/$USER
export VAGRANT_HOME=/tmp/$USER
export VAGRANT_CWD=${HOME}

###########################################################################
#                Main logic - infinite loop                               #
###########################################################################




#default number of machine = 1
function defaultmachines()
{

	if [ -z "$no_machine" ]
	then 
    	no_machine=1
	elif [ "$no_machine" == 0 ]
	then
		echo "please give reasonable number of machine"
		exit
	fi
   

   	
   	if [ ! -z "$xdisk" ]
	then
			val=$(ls $diskDirectory|grep -o $xdisk) 
		if [[ -z "$val" && -z "$diskVolumeSize" ]]
		then
			diskVolumeSize=1024
		fi	
		
			num=$(ls /home/ladmin/|grep Vagrantfile)		
		if  [ ! -z "$num" ]
		then
	    	num=$(grep $xdisk $Default_VagFile)		
			if ! [[ -z "$num" ]]
			then
        		echo "this disk is attached to other machine"
				exit     
    		fi
		fi
	    
		
		if [ ! -z "$xdisk" ]
   		then
			check=$(ls ${diskDirectory}| grep $xdisk)
			if [[ ! -z "$check" && ! -z "$diskVolumeSize" ]]   
			then
				echo -e "$xdisk is pre-configured it cannot accept volume\nplease use $basecommand update -n <machine> -d <disk> -v < volume>"
				exit
			fi
	    fi 
	fi
}



# secondary disk information
function diskInformation()
{

   VBoxManage list hdds   
	
}

#single disk information
function singleDiskinfo()
{
	val=$(ls $diskDirectory|grep -o $xdisk)
	if [ ! -z "$val" ]
	then
		VBoxManage list hdds|grep -C 4 $xdisk
		exit
	else
		echo "there is no disk with this name"
	fi

}


#list of disk 
function listDisk()
{

	val=$(ls $diskDirectory)
	
	if [ -z "$val" ]
	then
		echo -e "there is no disk"
		exit
		else
    	ls $diskDirectory
	fi
}


#find to which machine disk is attached
function attachedDiskInfo()
{
     
    check=$(ls $diskDirectory| grep -ow $xdisk)
	if [ -z "$check" ]
	then
		echo "no disk is present with this name please check disk information"
		else
		val=$(grep -w $xdisk $Default_VagFile|grep storageattach|cut -d'.' -f1)
		machine=$(echo $val|cut -d'.' -f1)
		if [ ! -z "$val" ]
		then
    		echo "$xdisk is attached to $machine"
			else
    		echo "$xdisk is not attached to any machine"
    	fi
	fi
}

#checking for numeric values
function numericValuesValidate()
{
	if [ ! -z "$no_machine" ]
	then
		checkNumericValue=$no_machine
	elif [ ! -z "$diskVolumeSize" ]
	then
		checkNumericValue=$diskVolumeSize
	fi
	

	if ! [[ "$checkNumericValue" =~ ^[0-9]+$ ]] 
	then
		echo "please enter numeric value "
		exit
	elif [ "$checkNumericValue" -eq 0 ]
	then
		echo "please give reasonable value"
		exit
	fi
	
	val=$(echo "$checkNumericValue"|cut -c1)
	if [ "$val" == 0 ]
	then 
		checkNumericValue=$(echo "$checkNumericValue"|cut -c2-)
	fi

	if [ ! -z "$no_machine" ]
	then
		no_machine=$checkNumericValue
		elif [ ! -z "$diskVolumeSize" ]
		then
		diskVolumeSize=$checkNumericValue
	fi
}

#checking numerical value for RAM
function ramInputValidation()
{
	if [ "$RAM" == 0 ]
	then
		echo "please enter some reasonable value you entered zero"
		exit
    fi    

    suff=`expr "$RAM"| grep -o '.$'` 
    if ! [[ "$suff" == G || "$suff" == g || "$suff" == M || "$suff" == m ]]
	then
		echo "please enter RAM for GB 'G' 'g'  or for MB 'M' 'm' as suffix"
		exit
	fi

	pref=`expr "$RAM" | sed 's/.$//'`
	if ! [[ "$pref" =~ ^[0-9]+$ ]]
	then
		echo -e "please enter numeric value in RAM\nexample 1G|1g  512M|512m"
		exit
		elif [ "$pref" == 0 ]
		then
			echo "please enter some reasonable value you entered zero"
			exit
    fi    
}

#checking numerical value for cpu
function cpuInputValidation()
{
	if ! [[ "$CPU" =~ ^[0-9]+$ ]]
	then
		echo "please enter numeric value in CPU"
		exit
	elif [ "$CPU" == 0 ]
	then
		echo "please enter reasonable value you entered zero"
		exit
	fi

}





#disk deattach
function diskRemove()
{  
    val=$(grep $machine $Default_VagFile|grep storageattach)
	if [ -z "$val" ]
	then
		echo "no disk attached to machine"
		exit
	fi
    
	val=$( grep $machine $Default_VagFile|sed -n 2p|cut -d '.' -f1)
	if [ -z "$val" ]
	then
		echo -e "you may enter wrong machine name\nplease enter correct machine name"
		exit
	fi
    
	existDisk=$(grep -n $machine $Default_VagFile| grep storageattach | cut -d: -f1)
	val=$(grep -n $machine $Default_VagFile| grep -o createhd)
	if [ ! -z "$val" ] 
	then
		val=$(VBoxManage list hdds | grep $machine | grep vmdk | cut -d'/' -f5)
		VBoxManage storageattach ${val} --storagectl 'IDE Controller' --port 1 --device 0 --medium none 2> /dev/null 
		
		line=$(grep -n $machine $Default_VagFile| grep createhd |cut -d: -f1)
		line=$(($line-1))
		
		for ((i=1;i<=4;i++))
		do
			sed -i "${line}d" $Default_VagFile
		done
		echo "disk of ${machine} was deattached"
	elif [ ! -z "$existDisk" ]
	then
		val=$(VBoxManage list hdds | grep $machine | grep vmdk | cut -d'/' -f5)
		VBoxManage storageattach ${val} --storagectl 'IDE Controller' --port 1 --device 0 --medium none 2> /dev/null 
         
	    lineNo=$(grep -n $machine $Default_VagFile| grep storageattach | cut -d: -f1|cut -d: -f1)
		sed -i "${lineNo}d" $Default_VagFile
		echo "disk of ${machine} was deattached"    
	fi
	
}

#checking update volume of disk with current volume
function compare_with_old_volume()
{
	if ! [[ -z "$xdisk" && -z "$diskVolumeSize" ]]
	then
		val=$(VBoxManage list hdds|grep -A 2 $xdisk|tail -n 1|awk {'print $2'})
		if [[ "$val" > "$diskVolumeSize" ]]
		then
			echo -e "$xdisk current volume is $val.MB please update more then this\nshrinking of disk volume is not applicable"
			exit
		fi
    fi
}


#updating memory,cpu,disk
function updateVm()
{
#for update disk	 

if [ ! -z "$xdisk" ]
then
    
	if [ -z "$machine" ]
	then
		echo -e "please enter machine name\n$basecommand update -n <machine> -d <value> -m <value> -c <value>"
		exit
	fi
     
	val=$(vagrant status|grep -w $machine|awk {'print $2'})
	if [ "$val" == running ]
	then
		echo -e "please shutdown machine then update\n$basecommand shutdown -n <machine>"
		exit
	fi 

	check=$(grep $machine $Default_VagFile | grep storageattach)
	if [ -z "$check" ]
	then
		echo -e "disk is not attached to machine please check\nplease attach disk then update disk"
		exit	
    fi
	
	val=$(vagrant status|grep $machine|awk {'print $2'})
	if [ "$val" == not ]
	then
		echo -e "please start machine once then update disk\n$basecommand start -n <machine>"
		exit
	fi
	
	if [ ! -z "$xdisk" ]
    then
		if [[ -z "$diskVolumeSize" && "$diskVolumeSize" -eq 0 ]]
		then
			echo -e "please give disk volume\n$basecommand update -n <machine> -d <name.vdi> -v <disk volume>"
			exit
		fi
	fi
    
	check=$(grep $machine $Default_VagFile |grep storageattach|cut -d'/' -f5|cut -d"'" -f1)

    if ! [ "$xdisk" == "$check" ]
 	then
		echo "$xdisk disk is not attached to $machine"
		exit
	fi


	if [[ ! -z "$diskVolumeSize" && ! -z "$xdisk" ]]
    then
        uuid=$(VBoxManage list hdds|grep -B 4 $xdisk|grep -i uuid| head -n 1|cut -d: -f2)
        VBoxManage modifyhd $uuid --resize $diskVolumeSize
		echo -e "$xdisk was updated to $diskVolumeSize.MB please start machine\n$basecommand start -n <machine>"
		
		val=$(grep -n $machine $Default_VagFile | grep $xdisk|grep createhd|cut -d: -f1)		
		if [ ! -z "$val" ]
		then
			sed -i "${val}d" $Default_VagFile
			sed -i "${val}i \                     \ $machine.customize ['createhd', \'--filename','/home/ladmin/.Vmdisk/$xdisk', \'--variant', 'Standard', \'--size', $diskVolumeSize]" $Default_VagFile
		fi
	fi	
fi  

	if [[ -z "$CPU" && -z "$xdisk" && -z "$RAM" ]]
	then
		echo "please enter some value to update"
		exit
	fi

 # please restart machine after every update
 # for update CPU
if [ ! -z "$CPU" ]
then

	if [ -z "$machine" ]
	then
		echo -e "please enter machine name\n$basecommand update -n <machine> -d <value> -m <value> -c <value>"
		exit
	fi

	if [[ ! -z "$CPU" && "$CPU" -le "$availableCPUs" ]]
    then
		val=$(cat -n $Default_VagFile | grep $machine | grep '\--cpus'|awk {'print $1'})
		sed -i "${val}d" $Default_VagFile
		sed -i "${val}i \                       \ $machine.customize [\"modifyvm\", :id, \"--cpus\", \"$CPU\"]" $Default_VagFile
		echo "CPU of $machine was updated to $CPU"
    fi
	if [ "$CPU" -gt "$availableCPUs" ]
	then
		echo "machine have only $availableCPUs cpu please give under this"
		exit
	fi	   
fi
 #for update RAM

if [ ! -z "$RAM" ]
then
	
	if [ -z "$machine" ]
	then
		echo -e "please enter machine name\n$basecommand update -n <machine> -d <value> -m <value> -c <value>"
		exit
	fi
	
	changeRAMtoMB
	if [[ ! -z "$RAM" && "$RAM" -lt "$minMemory" ]]
    then
    	echo "minimum value for memory is 512M please enter above this"
    	RAM=512
		exit
    elif [ "$RAM" -gt "$availableMaxMemory" ]
    then
    	echo "machine have only $availableMaxMemory.MB or 6.53GB memory please give under this"
    	exit
    fi
    if [[ ! -z "$RAM" && "$RAM" -lt "$availableMaxMemory" ]]
    then
		val=$(cat -n $Default_VagFile | grep $machine| grep '\--memory'|awk {'print $1'})
		sed -i "${val}d" $Default_VagFile
		sed -i "${val}i \                       \ $machine.customize [\"modifyvm\", :id, \"--memory\", \"$RAM\"]" $Default_VagFile
		echo "memory of $machine was updated to $RAM.MB"
    fi  
fi
	echo "to start vm '$basecommand start -n <machine>'"

}				



# function to delete individual machine
function deleteMachine()
{
	if [ -z "$machine" ]
	then
		exit
	fi
 	check=$(ls ~|grep Vagrantfile )
	 if [ -z "$check" ]
	 then
	 	echo "there is no vm present"
	 	exit
	 fi

	val=$(grep -wo $machine $Default_VagFile|head -n 1 )
	if [ -z "$val" ]
	then
		echo -e "may be machine is not configured with this name\nmay be machine name is incorrect"
		exit
	fi

	val=$(vagrant status 2> /dev/null|grep -w $machine|awk {'print $2'})
	if [ $val == running ]
	then
		vagrant halt $machine 
	fi
    

	val=$(grep $machine $Default_VagFile|grep -o storageattach)
	if [ ! -z "$val" ]
	then
		diskRemove 
	fi

	val=$(grep -n $machine $Default_VagFile | head -n 1|cut -d: -f1)
	num=$(grep -n $machine $Default_VagFile | tail -n 1|cut -d: -f1)		
	if [ -z "$val" ]
	then
		echo "no machine present with this name"
		else 
		vagrant destroy -f $machine 2> /dev/null
	
		for ((i=${val};i<=${num}+2;i++))
		do
		sed -i "${val}d" $Default_VagFile
		done
	    echo "$machine was deleted"
	fi
	
	val=$(grep cpu $Default_VagFile)
	if [ -z "$val" ]
	then 
		rm -rf $Default_VagFile
		exit
	fi
}


#delete single vm with disk 
function deleteVMWithDisk()

{

	if [ -z "$machine" ]
	then
		exit
	fi
 	check=$(ls ~|grep Vagrantfile )
	 if [ -z "$check" ]
	 then
	 	echo "there is no vm present"
	 	exit
	 fi

	val=$(grep -wo $machine $Default_VagFile|head -n 1 )
	if [ -z "$val" ]
	then
		echo -e "may be machine is not configured with this name\nmay be machine name is incorrect"
		exit
	fi

	val=$(vagrant status 2> /dev/null|grep -w $machine|awk {'print $2'})
	if [ $val == running ]
	then
		vagrant halt $machine 
	fi

	val=$(grep -n $machine $Default_VagFile | head -n 1|cut -d: -f1)
	num=$(grep -n $machine $Default_VagFile | tail -n 1|cut -d: -f1)		
	if [ -z "$val" ]
	then
		echo "no machine present with this name"
		else 
		vagrant destroy -f $machine 2> /dev/null
	
		for ((i=${val};i<=${num}+2;i++))
		do
		sed -i "${val}d" $Default_VagFile
		done
	    echo "$machine was deleted"
	fi
	
	val=$(grep cpu $Default_VagFile)
	if [ -z "$val" ]
	then 
		rm -rf $Default_VagFile
		all the vm are deleted 
		exit
	fi
}


#show machine information
function systemInfo()
{
	val=$(VBoxManage list vms |grep $machine |cut -d'"' -f2)
	VBoxManage showvminfo $val --details 

}



# Allocating secondary disk to machine at the time new machine creation
function diskAllocate()
{

	
	
	# if  [ ! -f "$Default_VagFile" ]
	# then
	# 	echo "there is no machine"
	# 	exit
	# fi
	
	if [ -z "$xdisk" ]
	then
    	echo -e "to start vm use command '$basecommand start -n <machine>'"
		exit
	fi
	
	if [[ "$diskVolumeSize" == 0 || -z "$diskVolumeSize" ]]
	then
		diskVolumeSize=1024
	fi
   
	val=$(ls ~| grep Vagrantfile) 
	if  [ ! -z "$val" ]
	then
    	num=$(grep -i $xdisk $Default_VagFile)
    	if ! [[ -z "$num" ]]
		then
        	echo "this disk is attached to other machine"     
    		exit  
    	fi
    fi
	
		val=$(ls $diskDirectory|grep $xdisk)
	if [ -z "$val" ]
	then
		if [[ ! -z "$xdisk" && ! -z "$diskVolumeSize" ]]
    	then
			val=$(grep -n $hostname $Default_VagFile| grep -A 1 provider | cut -d: -f1|tail -n 1)
			sed -i "${val}i \		    	   \ unless File.exist?('/home/ladmin/.Vmdisk/$xdisk')" $Default_VagFile
			val=$(($val+1))
			sed -i "${val}i \                       \ $hostname.customize ['createhd', \'--filename','/home/ladmin/.Vmdisk/$xdisk', \'--variant', 'Standard', \'--size', $diskVolumeSize]" $Default_VagFile
			val=$(($val+1))    
			sed -i "${val}i \                   \ end" $Default_VagFile
			val=$(($val+1))    
			sed -i "${val}i \                       \ $hostname.customize ['storageattach', :id,  \'--storagectl', 'IDE Controller', \'--port', 1, \'--device', 0, \'--type', 'hdd', \'--medium','/home/ladmin/.Vmdisk/$xdisk']" $Default_VagFile
			echo -e "$xdisk of volume $diskVolumeSize.MB is attached to $hostname machine"
			echo -e "to start vm use command '$basecommand start -n <machine>'"
			exit
        fi   
	    else
			val=$(grep -n $hostname $Default_VagFile| grep provider | cut -d: -f1)
			val=$(($val+1))    
			sed -i "${val}i \                       \ $hostname.customize ['storageattach', :id,  \'--storagectl', 'IDE Controller', \'--port', 1, \'--device', 0, \'--type', 'hdd', \'--medium','/home/ladmin/.Vmdisk/$xdisk']" $Default_VagFile
			echo "$xdisk is attached to $hostname machine"
			echo -e "to start vm use command '$basecommand start -n <machine>'"
	fi
}

#checking disk name
function diskNameValidation()
{
	if [ -z "$xdisk" ]
	then
		echo -e "please enter disk name\n$basecommand disk attach -n <machine> -d <disk> -v <volume>"
		exit
	fi
  
    val=$(echo $xdisk|grep -o '....$')
	if ! [ "$val" == .vdi ]
	then
		xdisk=`expr $xdisk.vdi`
	fi

}


# delete all machine
function deleteAllMachine()
{
	val=$(ls $Default_VagFile)
	if [ -z "$val" ]
	then
		echo " there is no Vagrantfile"
		exit
	fi
	vagrant halt
	vagrant destroy 
	rm -rf $Default_VagFile
	echo "all vms are deleted"
}


#showing running vms
function runningVm()
{
	val=$(ls ~|grep Vagrantfile)
	if [ ! -z "$val" ]
	then
		val=$(vagrant status 2> /dev/null|grep mydb|grep -w running)
		if [ ! -z "$val" ]
		then
			echo "Running machines are"
			echo "$val"
			echo -e "for shutdown vm use command '$basecommand shutdown -n <machine>'"
			else
			echo "there is no running vm"
		fi
		else
			echo "there is no running vm"
	fi
	exit
}


# checking for sub command or option
function shutdown_options()
{
	echo -e "please enter options \n-n  --name  -a  --all\nvmcreate shutdown <option> <machine name>"
	exit
}


#deattach options
deattach_options()
{
	if [ -z "$machine" ]
	then
		echo -e "please enter options \n-n  --name\nvmcreate disk deattach <option> <machine name>"
		exit
    fi
}

# restart options
function restart_options()
{
	echo -e "valid options are\n-a|--all   -n|--name"
	exit
}


#check machine to start
function start_options()
{
	echo -e "please enter options \n-n  --name   -a  --all\nvmcreate start <option> <machine name>"
	exit

}


#disk command options
function disk_options()
{
	echo -e "please enter options\nattach  deattach  del  info"
	exit

}

#checking for mahcine information

function sysinfo_options()
{
	echo -e "please enter options \n-n  --name\nvmcreate sysinfo <option> <machine name>"
	exit

}


#command for vm list help
function list_options()
{
	echo -e "please enter options \n-r  --running    -a   --all\nvmcreate list <option> <machine name>"
	exit

}


#command for delete vm
function delete_options()
{
	echo -e "please enter options \n-n  --name    -a   --all\nvmcreate delete <option> <machine name>"
	exit

}


#command for update vm
function update_options()
{
	echo -e "please enter options \n-n  --name    -d  --disk   -m   --memory   -c  --cpu\nvmcreate update <option> <machine name> <option> <value>"
	exit

}

#shutdown for all vms
function shutdownvm()
{
	val=$(vagrant status|grep mydbops|grep -w running)
	if [ -z "$val" ]
	then
		echo "there is no vm to shutdown"
		exit
		else
		vagrant halt 2> /dev/null
		echo "all vms are shutdown"
		exit
	fi

}

#disk attach command help
function diskAttach_options()
{

	if [[ -z "$machine" && -z "$xdisk" && "$diskVolumeSize" ]]
	then	
		echo -e "please enter command option \n-n  --name   -d  --disk  -v  --volume\nvmcreate disk attach <option> <machine name> <option> < value>"
		exit
	fi
}



#disk attach command help
function del_options()
{
	echo -e "please enter command option \n-d  --disk\nvmcreate disk del <option> < value>"
	exit
	
}


#check vm list
function vmchecklist()
{
	
	val=$(vagrant status 2> /dev/null|grep mydb) 
	if ! [ -z "$val" ]
	then
		echo "list of all vms"
		echo "$val" 
		else
		echo "there is no vm"
	fi
    exit
}

function update_options()
{ 
	echo -e "valid options are\n-n|--name  -d|--disk   -c|--cpu  -m|--memory"
	exit
}


function update_vagrant()
{
	if ! [[ -z "$RAM" && -z "$CPU" && -z "$xdisk" ]]
    then
    	updateVm
    	else 
    	update_options
    fi
}


#check diskinfo command help
function diskinfo_options()
{
	echo -e "please enter command option\n-d  --disk  -f  --find   a  --all   -l  --list\nvmcreate disk info <option> <value>"
	exit

}

#delete all vm fuction
function deleteall()
{

	vagrant destroy -f
	rm -rf $Default_VagFile
}


#check machine is shutdown or not before update system ,attach disk,deattach disk
function checkrun()
{
	val=$(vagrant status|grep $machine|grep -w running)
	if [ ! -z "$val" ]
	then
		echo -e "please shutdown machine then deattach disk\n$basecommand shutdown -n <machine>"
		exit
	fi

}


opt="$1"

	if [ ! -d ~/.Vmdisk ]
	then
		mkdir ~/.Vmdisk
	fi

case "${opt}" in

	"new")      
	    for arg in "$@"
		do
			case $arg in
			new)
				shift
			;;
			-n|--number)
				no_machine=$2
				# Validating numrical value in number of machines
				numericValuesValidate
				shift
				shift
			;;
			-c|--cpu)
				CPU=$2
				# Validating numrical value and number of cpu allocation
				cpuInputValidation
				shift 
				shift		
			;;
			-m|--memory)
				RAM=$2
				# Validating numrical value and memory alloaction
				ramInputValidation
				shift
				shift
			;;
			-d|--disk)
				xdisk=$2
				# Validating disk name 
				diskNameValidation
				shift
				shift
			;;
			-v|--volume)
				diskVolumeSize=$2
				# Validating disk volume size 
				numericValuesValidate
				shift
				shift
			;;
			*)
				if [[ ${!#} == $arg ]]
				then
        			echo -e "valid options are\n-n|--name  -c|--cpu  -m|--memory  -d|--disk  -v|--volume"
					exit
				fi
			;;
			esac

		done
		defaultmachines
		Creating_NewMachine
		
    ;;   
	
	"shutdown")           
		for arg in "$@"
		do
		case $arg in
		shutdown)
		;;
		-a|--all) 
			shutdownvm
			exit
		;;
		-n|--name)    
			for arg in $@
			do
			mname=$3
			# Validating machine name 
			machineNameValidation
			#shutdown individual machine
			Halt_Individual_Machines
			shift 
			done 
			exit
		;;
		*)
		if [[ ${!#} == $arg ]]
		then
			echo -e "valid options are\n-a|--all   -n|--name"
			exit
		fi
		;;
		esac 
		done 
		#options for shutdown command
		shutdown_options          
	;;
                      
	          		 
    "start")  
		for arg in "$@"
		do
		case $arg in
		start) 
			shift 
		;;
		-a|--all)
			uchoice=yes
			PowerOn_Machines 
			exit
		;;
		-n|--name)    
			for arg in $@
			do
			mname=$2
			# Validating machine name
			machineNameValidation
			PowerOn_Individual_Machines
			shift 
			done 
			exit
		;;
		*)
			if [[ ${!#} == $arg ]]
				then
				echo -e "valid options are\n-a|--all   -n|--name"
				exit
			fi
		;;
		esac 
		done 
		start_options
	;;
	          		  
 	        
		restart)  
					for arg in "$@"
					do  
					case $arg in
		restart)
				shift 
		;;
		-a|--all) 
					# validating there is any vm or not
					machineNameValidation
					uchoice=yes
					Restart_Machines 
					exit
		;;
		-n|--name)    
					for arg in $@
					do
					mname=$2
					# Validating machine name
					machineNameValidation
					Reload_Individual_Machines
					shift 
					done 
					exit
		;;
		*)
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid options are\n-a|--all   -n|--name"
			exit
			fi
		;;
			esac 
			done 
			restart_options
	    ;;
	
	"disk")
				
				for arg in "$@"
				do
				case $arg in
    "attach")
				for arg in "$@"
				do
				case $arg in
				attach)
				shift
		;;
		-n|--name)
					machine=$3
					# Validating machine name
					machineNameValidation
					shift
					shift
		;;
		-d|--disk)
					xdisk=$3
					diskNameValidation
					shift
					shift
		;;
		-v|--volume)
						diskVolumeSize=$3
						numericValuesValidate
						shift
						shift
		;;
		-*)
				if [[ ${!#} == $arg ]]
				then
				echo -e "valid options are\n-n|--name  -d|--disk   -v|--volume"
				exit
				fi
		;;
				esac
				done
				diskAttach_options
				diskAttach
        ;;
	
	"deattach")
					for arg in "$@"
					do
					case $arg in
					deattach)
					shift
		;;
        -n|--name)
					machine=$3
					# Validating machine name
					machineNameValidation
					;;
					-*)
					if [[ ${!#} == $arg ]]
					then
					echo -e "valid option are\n-n|--name"
					exit
					fi
		;;
					esac	
					done
					checkrun
					diskRemove
					deattach_options 
					exit
        ;;
    	"del")
					for arg in $@
					do
					case $arg in
					del)
					shift
		;;
		-d|--disk)
					xdisk=$3
					diskNameValidation
		;;
		-*)
				if [[ ${!#} == $arg ]]
				then
				echo -e "valid option are\n-d|--disk"
				exit
				fi
		;;
				esac
				done
				deleteSecondaryDisk
	    ;;
	"info")       
				for arg in $@
				do
				case $arg in
				info)
				shift
		;;
		-a|--all)
					diskInformation
					exit
		;;
		-f|--find)
					xdisk=$3
					diskNameValidation
					attachedDiskInfo
					exit
		;;
	    -d|--disk)
					xdisk=$3
					diskNameValidation
					singleDiskinfo
		;;
		-l|--list)
					listDisk
					exit
		;;
		-*)
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid option are\n-a|--all  -f|--find   -d|--disk   -l|--list"
			exit
			fi
		;;
			esac
			done
			diskinfo_options
		;;
			esac
			done
			disk_options
    ;;
	          	
	
	"sysinfo") 
				for arg in $@
				do
				case $arg in
				sysinfo)
				shift
		;;
		-n|--name)
					machine=$2
					# Validating machine name
					machineNameValidation
					systemInfo
					exit
		;;
		*)
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid option are\n-n|--name"
			exit
			fi
		;;
			esac
			done 
			sysinfo_options
	    ;;
	
	
	"list") 
			for arg in "$@"
			do  
			case $arg in
			list)
			shift
		;;
	    -r|--running)
						runningVm      
						exit
		;;
		-a|--all)
					vmchecklist
					exit 
		;;
		*)
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid option are\n-r|--running   -a|--all"
			exit
			fi
		;;
			esac
			done
			list_options
		;;

	"exit")    
			Exit_Script  ;;

	"delete")     
				for arg in "$@"
				do  
				case $arg in
				delete)
				shift 
		;;
		-a|--all) 
					Delete_All_Machine
					exit
		;;
		-n|--name)    
					for arg in $@
					do
					machine=$2
					deleteMachine
					shift
					done
					exit
		;;
		-af|--allforce)
				Delete_All_Machine_with_disk
		;;
		-f|--force)
					for arg in $@
					do
						machine=$2
						deleteVMWithDisk
						shift
					done
					exit			
		;;				
		*)
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid option are\n-n|--name   -a|--all"
			exit
			fi
		;;
			esac 
			done 
			delete_options
	    ;;
	          	
    "update")
				for arg in "$@"
				do
				case $arg in
				update)
				shift
		;;
		-n|--name)
					machine=$2
					# Validating machine name
					machineNameValidation
					shift
					shift
		;;
		-c|--cpu)
					CPU=$2
					cpuInputValidation
					shift
					shift
		;;
		-m|--memory)
						RAM=$2
						ramInputValidation
						shift
						shift
		;;						
		-d|--disk)
					xdisk=$2
					diskNameValidation
					shift
					shift
		;;
		-v|--volume)
						diskVolumeSize=$2
						numericValuesValidate
						compare_with_old_volume
						shift
						shift
		;;
		*)	
			if [[ ${!#} == $arg ]]
			then
			echo -e "valid options are\n-n|--name  -d|--disk   -c|--cpu  -m|--memory"
			exit
			fi
		;;
			esac
			done 
			update_vagrant
		;;
	
	"ssh")
			machine=$2
			if [ -z "$machine" ]
			then
			echo -e "enter machine name or press <tab>"
			exit
			fi
			# Validating machine name
			machineNameValidation
			vagrant ssh $machine
		;;
			  
	--help|-h)  
					showMenu
		 ;;  
	-v|--version)
		 	echo -e "version 2.0\nDeveloped by Lalit kumar and Lalit Kumar\nfor bugs https://echo.mydbops.com/projects/vmcreate"
		;;		
	*)  
			echo "PLEASE ENTER CORRECT COMMNAND OR TYPE $basecommand --help|-h" 
			exit
	    ;; 
				              
esac
                         
        





