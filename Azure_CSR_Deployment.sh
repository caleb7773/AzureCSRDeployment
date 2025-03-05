#!/bin/bash
starttime=$(date)
PATHER=$(pwd)
trap ctrl_c INT
function ctrl_c() {
	rm -rf ${PATHER}/${project_code}*
	echo && echo && echo
 	echo && echo && echo
	echo -e "${GREEN}Please let this finish...${NC}"
	echo -e "${RED}Deleting any created Azure Resources to prevent charges${NC}"
 	echo
  	echo "This can take a few minutes. If you do not have time, please go to portal.azure.com"
   	echo "  and delete ${RESOURCE_GROUP} when you have time."
    	echo
     	echo -e "If you are trying to start another job, just open a new ${GREEN}Terminal${NC}"
      	echo "  and let this one finish in the background."
	az group delete --name ${RESOURCE_GROUP} ############## > /dev/null
 	exit
}
project_code=${RANDOM}
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

clear
if [[ ! -f startup-config ]]; then echo "Router Configuration needs to be in this directory saved as "startup-config""; exit 1 ; fi


# Suggests hardware types for deployment

    #Standard_DS4_v2 ($427 per month) [Maybe 4?]
    #Standard_DS3_v2 ($213 per month) [Maybe 3?]
    #Standard_DS2_v2 ($106 per month) [Max of 2 Network adapters allowed]
VmHwType="Standard_DS3_v2"
USERNAME="standarduser"
Image="cisco:cisco-c8000v-byol:17_16_01a-byol:17.16.0120250107"


# Kill the script if someone runs it as root

if [[ $(id -u) == 0 ]];
then
	echo
	echo "Do not run this as root you joker!"
	exit 1
fi

# Check dependancies
curl --version
if [[ $? != 0 ]];
then
	clear
	echo " Curl Missing... "
   	echo " Standby while we deploy curl"
	sudo apt update -y && sudo apt upgrade -y
	sudo apt install curl -y
fi

az --version
if [[ $? != 0 ]];
then
	clear
	echo " AZ CLI Missing... "
   	echo " Standby while we deploy AZ CLI Dependancies"
    	sudo apt update -y && sudo apt upgrade -y
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash -x
fi

# Generate SSH Key if it does not exist

if [[ -f ~/.ssh/id_rsa ]]; 
then 
	echo "SSH Keyfile exists"
else 
	echo "SSH Keyfile does not exist"
	ssh-keygen -N "" -o -f ~/.ssh/id_rsa
fi






# Connect to Azure CLI
az account show
if ! [[ ${?} == 0 ]];
then
	az login
fi



builder_menu() {
# This function will create a display for the end user to see what they have done
clear
echo
echo " #############################################################################"
echo " #############################################################################"
echo " ###                                                                       ###"
echo -e " ###        ${GREEN}We need the following information for your Redirector Pair${NC}     ###"
echo " ###                                                                       ###"
echo " #############################################################################"
echo " #############################################################################"
echo " ###  " 
echo -e " ###    ${GREEN}Your Choices:${NC} "  
echo " ###  "
echo -e " ###  ${GREEN}Subscription Name:${RED} ${SUBSCRIPTION_NAME}${NC}"
echo -e " ###  ${GREEN}Project Name:${RED} ${PROJECT}${NC}"
echo " ###  "
echo -e " ###  ${GREEN}Region:${RED} ${REGION}${NC}"
echo " ###"
echo " #############################################################################"
echo " #############################################################################"
echo
}

# Setting the choice variable to "N" will allow it loop on the first iteration
choice=N

builder_variables() {
# This function will interact with the user to receive inputs
while [[ "${choice}" != [y/Y] ]];
do
	clear
 	# Reach out to Azure and grab the subscriptions this user has access to.
  	echo  -e " What subscription do you want to deploy in ${GREEN}(s2vaus-sandbox-tactical)${NC}?"
  	echo  -e " If you press ${RED}ENTER${NC} you will pick the default value."
   	echo  -e " ${GREEN}Pick the number${NC} corresponding to your choice"
   	echo
	num=1
	az account list | grep s2vaus | cut -d '"' -f4 | sort -u > ${project_code}-subs.list
	
	for i in $(cat ${project_code}-subs.list);
	do 
		echo " (${num}) ${i}"
		((num++))
	done > ${project_code}-output.list
	rm -rf ${project_code}-subs.list
	echo -e "${GREEN}"
	cat ${project_code}-output.list
	echo -e "${NC}"
    	echo
	read -N 1 -p " Number is -> " SUBSCRIPTION_NAME
 	SUBSCRIPTION_NAME=$(cat ${project_code}-output.list | head -${SUBSCRIPTION_NAME} | tail -1 | cut -d ' ' -f3)
 	rm -rf ${project_code}-output.list
	if [[ -z "${SUBSCRIPTION_NAME}" ]];
	then
		SUBSCRIPTION_NAME=s2vaus-sandbox-tactical
	fi
	SUBSCRIPTION=$(az account list | grep "\"${SUBSCRIPTION_NAME}\"" -B 3 | grep id | cut -d '"' -f4)
	echo
	
	# Connect to Azure Subscription
	az account set -s ${SUBSCRIPTION}
	clear
	echo -e " ${RED}Azure Regions:${NC}"

echo "		North America"
echo -e "${GREEN} westus - westus2 - westus3${NC}"
echo -e "${GREEN} westcentralus - northcentralus - southcentralus - centralus${NC}"
echo -e "${GREEN} eastus - eastus2${NC}"
echo -e "${GREEN} canadacentral - canadaeast${NC}"

echo "		Europe"
echo -e "${GREEN} northeurope - westeurope - francecentral${NC}"
echo -e "${GREEN} ukwest - uksouth - switzerlandnorth - germanywestcentral${NC}"
echo -e "${GREEN} norwayeast - swedencentral - polandcentral - italynorth${NC}"

echo "		Asia"
echo -e "${GREEN} eastasia - southeastasia${NC}"
echo -e "${GREEN} centralindia - southindia - westindia${NC}"
echo -e "${GREEN} japaneast - japanwest${NC}"
echo -e "${GREEN} koreacentral - koreasouth${NC}"

echo "		South America"
echo -e "${GREEN} brazilsouth${NC}"
	
echo "		Australia"
echo -e "${GREEN} australiaeast - australiasoutheast - australiacentral${NC}"

echo "		Middle East"
echo -e "${GREEN} uaenorth - qatarcentral${NC}"

echo "		Africa"
echo -e "${GREEN} southafricanorth${NC}"
echo
echo "#############################################################################"
echo "#############################################################################"

	echo	
	echo
	echo
	echo -e " Where do you want the ${GREEN}CSR located${NC} ${RED}(eastus)${NC}?"
	read -p " > " REGION
	if [[ -z "${REGION}" ]];
	then
		REGION=eastus
	fi
 	echo
 	echo "Validating Region Choice..."
	output=$(az account list-locations -o table)
	if [[ "${output}" != *${REGION}* ]];
	then
		clear
	 	echo -e "${RED} ${REGION} - doesn't exists!${NC}"
	  	echo -e "Please pick a ${GREEN}region from the list${NC}"
	   	echo
		read -p "Press ENTER to try again" ENTER
	     	builder_variables
	fi
	region_skus=$(az vm list-sizes --location "${REGION}" -o table)
 	if [[ ${region_skus} != *${VmHwType}* ]]; 
 	then 
		clear
	 	echo -e "${RED} ${REGION} - doesn't support the VM SKU type!${NC}"
	  	echo -e "Please pick a ${GREEN}different region from the list${NC}"
	   	echo
		read -p "Press ENTER to try again" ENTER
	     	builder_variables
 	fi
  	echo
 	echo "Grabbing Resource Groups in your region..."
  	echo
	az group list | grep "\"${SUBSCRIPTION_NAME}-${REGION}-" | cut -d '"' -f4 | sort -u > ${project_code}-groups.list
	clear
	if [[ $(cat ${project_code}-groups.list | wc -l) -eq 0 ]];
	then
		echo
	else
		echo
		echo -e " The following Resource Groups are ${RED}already in this region${NC}"
		echo 
		echo -e "${GREEN}"
		cat ${project_code}-groups.list
		echo -e "${NC}"
		echo
		echo -e " ${RED}Do not overlap with any previous Resource Groups${NC}"
		echo
		echo
		echo
	fi
	rm -rf ${project_code}-groups.list
	echo -e " What would you like to name your Project ${GREEN}(twister)${NC}?"
	echo -e " ${GREEN}twister${NC} would be -> ${SUBSCRIPTION_NAME}-${REGION}-${GREEN}twister${NC}-TP_NE-rg"

	read -p " > " PROJECT
	if [[ -z "${PROJECT}" ]];
	then
		PROJECT=twister
	fi
	RESOURCE_GROUP=${SUBSCRIPTION_NAME}-${REGION}-${PROJECT}-TP_NE-rg
   	echo
 	echo "Validating Resource Group Choice..."
	output=$(az group show --name ${RESOURCE_GROUP} 2> /dev/null)
	if [[ "${output}" == *Succeeded* ]];
	then
		clear
	 	echo -e "${RED}Resource Group Already Exists!${NC}"
	  	echo -e "Please pick a ${GREEN}different project name or region${NC}"
	   	echo
		read -p "Press ENTER to try again" ENTER
	     	builder_variables
	fi
	builder_menu
	clear
	echo -e " ${RED}Azure Regions:${NC}"

echo "		North America"
echo -e "${GREEN} westus - westus2 - westus3${NC}"
echo -e "${GREEN} westcentralus - northcentralus - southcentralus - centralus${NC}"
echo -e "${GREEN} eastus - eastus2${NC}"
echo -e "${GREEN} canadacentral - canadaeast${NC}"

echo "		Europe"
echo -e "${GREEN} northeurope - westeurope - francecentral${NC}"
echo -e "${GREEN} ukwest - uksouth - switzerlandnorth - germanywestcentral${NC}"
echo -e "${GREEN} norwayeast - swedencentral - polandcentral - italynorth${NC}"

echo "		Asia"
echo -e "${GREEN} eastasia - southeastasia${NC}"
echo -e "${GREEN} centralindia - southindia - westindia${NC}"
echo -e "${GREEN} japaneast - japanwest${NC}"
echo -e "${GREEN} koreacentral - koreasouth${NC}"

echo "		South America"
echo -e "${GREEN} brazilsouth${NC}"
	
echo "		Australia"
echo -e "${GREEN} australiaeast - australiasoutheast - australiacentral${NC}"

echo "		Middle East"
echo -e "${GREEN} uaenorth - qatarcentral${NC}"

echo "		Africa"
echo -e "${GREEN} southafricanorth${NC}"
echo
echo "#############################################################################"
echo "#############################################################################"



	builder_menu
	echo -e " Do these options look correct? ${GREEN}[Y${NC}/${RED}N]${NC}"
	read -p " > " choice
done
}




builder_variables




clear
VNET1=${SUBSCRIPTION_NAME}-${REGION}-CSR1-vnet
V_SUBNET1_NAME=VNIC1-sub
V_SUBNET1=10.1.101.0/24
V_SUBNET1_IP=10.1.101.5
V_SUBNET2_NAME=VNIC2-sub
V_SUBNET2=10.1.102.0/24
V_SUBNET2_IP=10.1.102.5
V_SUBNET2_GW=10.1.102.5
V_SUBNET3_NAME=VNIC3-sub
V_SUBNET3=10.1.103.0/24
V_SUBNET3_IP=10.1.103.5
V_SUBNET3_GW=10.1.103.5
V_SUBNET4_NAME=VNIC4-sub
V_SUBNET4=10.1.104.0/24
V_SUBNET4_IP=10.1.104.5
V_SUBNET4_GW=10.1.104.5
NSG1=${SUBSCRIPTION_NAME}-${REGION}-VNIC1-nsg
NSG2=${SUBSCRIPTION_NAME}-${REGION}-VNIC2-nsg
NSG3=${SUBSCRIPTION_NAME}-${REGION}-VNIC3-nsg
NSG4=${SUBSCRIPTION_NAME}-${REGION}-VNIC4-nsg
VNIC1=${SUBSCRIPTION_NAME}-${REGION}-CSR1-vnic
VNIC2=${SUBSCRIPTION_NAME}-${REGION}-CSR2-vnic
VNIC3=${SUBSCRIPTION_NAME}-${REGION}-CSR3-vnic
VNIC4=${SUBSCRIPTION_NAME}-${REGION}-CSR4-vnic
VNIC1_IP=${SUBSCRIPTION_NAME}-${REGION}-VNIC1-ip
VNIC2_IP=${SUBSCRIPTION_NAME}-${REGION}-VNIC2-ip
VNIC3_IP=${SUBSCRIPTION_NAME}-${REGION}-VNIC3-ip
VNIC4_IP=${SUBSCRIPTION_NAME}-${REGION}-VNIC4-ip
VMNAME=CSR_Testing_Router

azurestarttime=$(date)
# Create a new Resource Group
echo -e "${NC}Creation has begun on - ${RESOURCE_GROUP}${RED}"
echo -e "${RED}"
az group create \
    --name ${RESOURCE_GROUP} \
    --location ${REGION} > /dev/null
username=$(az account show | grep onmicrosoft | cut -d '@' -f1 | cut -d '"' -f4)
grouppy=$(az group show -n ${RESOURCE_GROUP} --query id --output tsv)
az tag create --resource-id $grouppy --tags UserAzure=${username} Persistent=unknown UseCase=unknown Scripted=TechAzurePanda > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${RESOURCE_GROUP}${NC}"
first_instance() {
echo -e "${NC}Creation has begun on - ${VNET1}${RED}"
echo -e "${RED}"
az network vnet create \
    --name ${VNET1} \
    --resource-group ${RESOURCE_GROUP} \
    --address-prefix 10.1.0.0/16 \
    --location ${REGION} \
    --subnet-prefixes ${V_SUBNET1} ${V_SUBNET2} ${V_SUBNET3} ${V_SUBNET4} > /dev/null	
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNET1}${NC}"

echo -e "${NC}Creation has begun on - ${V_SUBNET1_NAME}${RED}"
echo -e "${RED}"
az network vnet subnet create \
    --name ${V_SUBNET1_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET1} \
    --address-prefixes ${V_SUBNET1} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${V_SUBNET1_NAME}${NC}"    

echo -e "${NC}Creation has begun on - ${V_SUBNET2_NAME}${RED}"
echo -e "${RED}"
az network vnet subnet create \
    --name ${V_SUBNET2_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET1} \
    --address-prefixes ${V_SUBNET2} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${V_SUBNET2_NAME}${NC}"    
    
echo -e "${NC}Creation has begun on - ${V_SUBNET3_NAME}${RED}"
echo -e "${RED}"
az network vnet subnet create \
    --name ${V_SUBNET3_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET1} \
    --address-prefixes ${V_SUBNET3} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${V_SUBNET3_NAME}${NC}"    
   
    
echo -e "${NC}Creation has begun on - ${V_SUBNET4_NAME}${RED}"
echo -e "${RED}"
az network vnet subnet create \
    --name ${V_SUBNET4_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET1} \
    --address-prefixes ${V_SUBNET4} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${V_SUBNET4_NAME}${NC}" 




echo -e "${NC}Creation has begun on - ${NSG1}${RED}"
echo -e "${RED}"
az network nsg create \
    --resource-group ${RESOURCE_GROUP} \
    --location ${REGION} \
    --name ${NSG1} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${NSG1}${NC}"

echo -e "${NC}Creation has begun on - ${VNIC1_IP}${RED}"
echo -e "${RED}"
az network public-ip create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC1_IP} \
    --sku Standard \
    --location ${REGION} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC1_IP}${NC}"

echo -e "${NC}Creation has begun on - ${VNIC1}${RED}"
echo -e "${RED}"
az network nic create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC1} \
    --vnet-name ${VNET1} \
    --location ${REGION} \
    --subnet ${V_SUBNET1_NAME} \
    --network-security-group ${NSG1} \
    --ip-forwarding true \
    --private-ip-address ${V_SUBNET1_IP} \
    --private-ip-address-version IPv4 \
    --public-ip-address ${VNIC1_IP} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC1}${NC}"

echo -e "${NC}Modification has initiated on - ${NSG1}${RED}"
echo -e "${RED}"
az network nsg rule create \
    --resource-group ${RESOURCE_GROUP} \
    --nsg-name ${NSG1} \
    --name SSH-rule \
    --priority 300 \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --description "Allow SSH" > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished modifying for SSH - ${NSG1}${NC}"
}

second_instance() {

echo -e "${NC}Creation has begun on - ${VNIC2_IP}${RED}"
echo -e "${RED}"
az network public-ip create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC2_IP} \
    --sku Standard \
    --location ${REGION} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC2_IP}${NC}"

echo -e "${NC}Creation has begun on - ${NSG2}${RED}"
echo -e "${RED}"
az network nsg create \
    --resource-group ${RESOURCE_GROUP} \
    --location ${REGION} \
    --name ${NSG2} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${NSG2}${NC}"



echo -e "${NC}Creation has begun on - ${VNIC2}${RED}"
echo -e "${RED}"
az network nic create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC2} \
    --vnet-name ${VNET1} \
    --location ${REGION} \
    --subnet ${V_SUBNET2_NAME} \
    --network-security-group ${NSG2} \
    --ip-forwarding true \
    --private-ip-address ${V_SUBNET2_IP} \
    --private-ip-address-version IPv4 \
    --public-ip-address ${VNIC2_IP} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC2}${NC}"
}
third_instance() {

 
echo -e "${NC}Creation has begun on - ${VNIC3_IP}${RED}"
echo -e "${RED}"
az network public-ip create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC3_IP} \
    --sku Standard \
    --location ${REGION} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC3_IP}${NC}"

echo -e "${NC}Creation has begun on - ${NSG3}${RED}"
echo -e "${RED}"
az network nsg create \
    --resource-group ${RESOURCE_GROUP} \
    --location ${REGION} \
    --name ${NSG3} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${NSG3}${NC}"




echo -e "${NC}Creation has begun on - ${VNIC3}${RED}"
echo -e "${RED}"
az network nic create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC3} \
    --vnet-name ${VNET1} \
    --location ${REGION} \
    --subnet ${V_SUBNET3_NAME} \
    --network-security-group ${NSG3} \
    --ip-forwarding true \
    --private-ip-address ${V_SUBNET3_IP} \
    --private-ip-address-version IPv4 \
    --public-ip-address ${VNIC3_IP} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC3}${NC}"
}
fourth_instance() {   
    
echo -e "${NC}Creation has begun on - ${VNIC4_IP}${RED}"
echo -e "${RED}"
az network public-ip create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC4_IP} \
    --sku Standard \
    --location ${REGION} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC4_IP}${NC}"


echo -e "${NC}Creation has begun on - ${NSG4}${RED}"
echo -e "${RED}"
az network nsg create \
    --resource-group ${RESOURCE_GROUP} \
    --location ${REGION} \
    --name ${NSG4} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${NSG4}${NC}"



echo -e "${NC}Creation has begun on - ${VNIC4}${RED}"
echo -e "${RED}"
az network nic create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNIC4} \
    --vnet-name ${VNET1} \
    --location ${REGION} \
    --subnet ${V_SUBNET4_NAME} \
    --network-security-group ${NSG4} \
    --ip-forwarding true \
    --private-ip-address ${V_SUBNET4_IP} \
    --private-ip-address-version IPv4 \
    --public-ip-address ${VNIC4_IP} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VNIC4}${NC}"
}



# Modify some files we will use later to test when the multithreading is complete
# We will delete these later in the script


echo n > ${project_code}-first_finished
echo n > ${project_code}-second_finished
echo n > ${project_code}-third_finished
echo n > ${project_code}-fourth_finished

# This is some fancy multithreading
# First it will run the first function and then the second function without waiting
first_instance && echo y > ${project_code}-first_finished
second_instance && echo y > ${project_code}-second_finished & third_instance && echo y > ${project_code}-third_finished & fourth_instance && echo y > ${project_code}-fourth_finished

while [[ $(cat ${project_code}-first_finished) != 'y' ]];
do
	sleep 1s
done
while [[ $(cat ${project_code}-second_finished) != 'y' ]];
do
	sleep 1s
done
while [[ $(cat ${project_code}-third_finished) != 'y' ]];
do
	sleep 1s
done
while [[ $(cat ${project_code}-fourth_finished) != 'y' ]];
do
	sleep 1s
done

rm -rf ${project_code}-first_finished
rm -rf ${project_code}-second_finished
rm -rf ${project_code}-third_finished
rm -rf ${project_code}-fourth_finished







vNet1Id=$(az network vnet show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${VNET1} \
  --query id --out tsv)
  
  
  
  
  
  
  
#echo -e "${NC}Peering has begun between - ${VNET1} and ${VNET2}${RED}"
#echo -e "${RED}"
#az network vnet peering create \
#  --name Peer_to_BE \
#  --resource-group ${RESOURCE_GROUP} \
#  --vnet-name ${VNET1} \
#  --remote-vnet $vNet2Id \
#  --allow-vnet-access > /dev/null
#echo -e "${NC}"
#  
#az network vnet peering create \
#  --name Peer_to_FE \
#  --resource-group ${RESOURCE_GROUP} \
#  --vnet-name ${VNET2} \
#  --remote-vnet $vNet1Id \
#  --allow-vnet-access > /dev/null
#echo -e "${NC}"
#echo -e "${GREEN}Finished Peering - ${VNET1} and ${VNET2}${NC}"
 
 
 


build_one() {
    


# Accept the VM Terms of Service
echo -e "${NC}Accepting terms of service on - ${VMNAME}${RED}"
az vm image terms accept --urn "${Image}" > /dev/null
echo -e "${GREEN}Finished accepting terms - ${VMNAME}${NC}"

# Create VM
echo -e "${NC}Creation has begun on - ${VMNAME}${RED}"
echo -e "${RED}"
az vm create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VMNAME} \
    --location ${REGION} \
    --image "${Image}" \
    --size "${VmHwType}" \
    --admin-username ${USERNAME} \
    --generate-ssh-keys \
    --nics ${VNIC1} ${VNIC2} ${VNIC3} ${VNIC4} > /dev/null
echo -e "${NC}"
echo -e "${GREEN}Finished - ${VMNAME}${NC}"
}

echo n > ${project_code}-vm1

build_one && echo y > ${project_code}-vm1

while [[ $(cat ${project_code}-vm1) != 'y' ]];
do
	sleep 1s
done


rm -rf ${project_code}-vm1




    
# Grabbing IP Addresses
export VM_1_Private_IP_ADDRESS=$(az vm show --show-details --resource-group ${RESOURCE_GROUP} --name ${VMNAME} --query privateIps --output tsv)
export VM_Public_IP_ADDRESS=$(az vm show --show-details --resource-group ${RESOURCE_GROUP} --name ${VMNAME} --query publicIps --output tsv)

VM_1_Public_IP_ADDRESS=$(echo ${VM_Public_IP_ADDRESS} | cut -d ',' -f1)
VM_2_Public_IP_ADDRESS=$(echo ${VM_Public_IP_ADDRESS} | cut -d ',' -f2)
VM_3_Public_IP_ADDRESS=$(echo ${VM_Public_IP_ADDRESS} | cut -d ',' -f3)
VM_4_Public_IP_ADDRESS=$(echo ${VM_Public_IP_ADDRESS} | cut -d ',' -f4)

if [[ -z ${VM_1_Private_IP_ADDRESS} ]];
then
	echo && echo && echo && echo
	echo "Frontend VM Failed to Deploy."
	echo "${REGION} - was unable to deploy your VM, pick another Region"
	echo "Do you want to delete the failed resource group - ${RESOURCE_GROUP}"
	az group delete -n ${RESOURCE_GROUP} --force-deletion-types Microsoft.Compute/virtualMachines
	exit
fi



clear
azurefinishtime=$(date)
echo -e " Your Router is not quite accessible yet, I'll let you know when SSH is ready for your connection"
echo -e " This is a Cisco thing in the background, the azure stuff is good."
echo
echo
echo
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
while [[ ${?} != 0 ]];
do
sleep 20s
clear
echo -e " Your Router is not quite accessible yet, I'll let you know when SSH is ready for your connection"
echo -e " This is a Cisco thing in the background, the azure stuff is good."
echo
echo
echo
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20 ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
done


clear



# Starting the licensing part
echo "This is your license reservation information"
echo
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20 ${USERNAME}@${VM_1_Public_IP_ADDRESS} << EOF
conf t
license smart reservation
exit
EOF

RequestCode=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20 ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'license smart reservation request all' | grep "Request code" | cut -d ':' -f2-)
clear
echo "Your Request code for Cisco is: "
echo "${RequestCode}"

################################################################################################
#
# I can do a test license from engineers but I can't burn it down without deactivating the license because it makes it hard to recoup that license #
#
################################################################################################
#
#
# TCL is a way to run a script on the router without needing to elevate to config t mode
# 
# Upload the TCL to the router, then SSH and call the script
#
#
###############################################################################################

echo -e "${RED} Router needs the license key${NC}"
echo
echo
read -rp "Please enter the File Name exactly from Cisco's Website including exetension: " filename
echo
echo
echo "Copy and Paste your license key now"
echo "(Press CTRL+D after copy is complete)"
read -rp 'Please enter the details: ' -d $'\04' data

echo ${data} > ${filename}

scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa ${filename} ${USERNAME}@${VM_1_Public_IP_ADDRESS}:${filename}


# Install the CSR Licensing file

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20 ${USERNAME}@${VM_1_Public_IP_ADDRESS} << EOF
license smart reservation install file bootflash:${filename}
config t
license boot level network-premier addon dna-premier
license accept end user agree
do write
EOF

# Reload required to fully accept the license

echo -e "${RED} Router needs a restart to apply license${NC}"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=20 ${USERNAME}@${VM_1_Public_IP_ADDRESS} << EOF
reload
yes
EOF
echo -e "${GREEN} Router restarted to apply configuration${NC}"
echo
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
while [[ ${?} != 0 ]];
do
sleep 60s
clear
echo -e "${GREEN} Router restarted to apply configuration${NC}"
echo
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
done

echo "Reboot Complete"
# Assign throughput level to 1Gig (Reboot is required before this command set)
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS}  << EOF
conf t
platform hardware throughput level MB 1000
EOF

# Check License and Throughput level
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS}  << EOF
show license all
show platform hardware throughput level
exit
EOF



#########################################
# Don't know if i need this anymore
# scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa startup-config ${USERNAME}@${VM_1_Public_IP_ADDRESS}:startup-config
#########################################
clear
echo
echo
# # # # # This might not be required # # # # # #
#echo -e "${RED} Router needs a restart to apply configuration${NC}"
#ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'reload'
#echo -e "${GREEN} Router restarted to apply configuration${NC}"
#echo
#ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
#while [[ ${?} != 0 ]];
#do
#sleep 60s
#clear
#echo -e "${GREEN} Router restarted to apply configuration${NC}"
#echo
#ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -o ConnectTimeout=60  ${USERNAME}@${VM_1_Public_IP_ADDRESS} 'show clock'
#done





# Lock out the SSH access from the NSG to harden the CSR



clear
echo
echo
echo -e " ${GREEN}Router completely deployed:${NC}"
echo -e "  Public IPs:"
echo -e "     vnic1 - ${VM_1_Public_IP_ADDRESS} - SSH Accessible currently"
echo -e "     vnic2 - ${VM_2_Public_IP_ADDRESS}"
echo -e "     vnic2 - ${VM_3_Public_IP_ADDRESS}"
echo -e "     vnic2 - ${VM_4_Public_IP_ADDRESS}"
echo
echo -e " ${GREEN} SSH IS READY! ${NC}"
echo
echo -e "   SSH into Router"
echo -e "      ssh -i ~/.ssh/id_rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa ${USERNAME}@${VM_1_Public_IP_ADDRESS}"
echo
echo 
echo " ${starttime} - Script initiated"
echo
echo " ${azurestarttime} - Azure Deployment started"
echo " ${azurefinishtime} - Azure Deployment completed"
echo
echo " ${azurefinishtime} - Cisco Configuration started"
echo " $(date) - Cisco Configuration completed"
