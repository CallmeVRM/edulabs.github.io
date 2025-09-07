#Spéciale Pluralsight
rg=$(az group list --query "[].name" --output tsv)

#Sinon déclarer le nom içi :
rg="prod-dev"
location="eastus"

#Resource Group
az group create -l $location -n $rg

########################################
########        Networking
########################################

#Variables
#---------
vnet_hub_name="vnet-hub"
vnet_hub_ip="10.0.0.0/16"

vnet_spoke_prod_front_name="vnet_spk_p_f_ip"
vnet_spk_p_f_ip="10.1.0.0/16"
subnet_spoke_prod_front_wordpress_name="sub_spk_p_b_dbwp"
sub_spk_p_f_wp_ip="10.1.1.0/24"

vnet_spoke_prod_back_name="vnet_spk_p_b"
vnet_spk_p_b_ip="10.2.0.0/16"
subnet_spoke_prod_back_dbwordpress_name="sub_spk_p_b_dbwp"
sub_spk_p_b_dbwp_ip="10.2.1.0/24"

name_nic_prod_front_wp_client1="wp_front_client1"
name_nic_prod_back_dbwp_client1="dbwp_back_client1"

name_vault_prod="edulabsVault-2"

name_ip_pub_bastion="ip-pub-bastion"
name_ip_pub_lb_prod_front="ip-pub-lb-prod-front"
name_ip_pub_vm_wp_front_temp="ip-pub-vm-temp"

name_vm_prod_front_wp_client1="wp-client01"
name_vm_prod_back_dbwp_client1="dbwp-client01"

name_nsg_prod_front="nsg-prod-front"
name_nsg_prod_back="nsg-prod-back"

bastion_hub_subnet="10.0.1.0/26"





#  Vnet   #
#----------

#vnet-hub
az network vnet create -g $rg -l $location --name $vnet_hub_name --address-prefix $vnet_hub_ip --subnet-name sub-hub --subnet-prefixes 10.0.0.0/24
#Récupérer l'ID :
id_vnet_hub=$(az network vnet show --name vnet-hub -g $rg --query id -o tsv)

#vnet spoke-prod-front
az network vnet create -g $rg -l $location --name $vnet_spoke_prod_front_name --address-prefix $vnet_spk_p_f_ip
#Récupérer l'ID :
id_vnet_spoke_prod_front=$(az network vnet show --name $vnet_spoke_prod_front_name -g $rg --query id -o tsv)


#vnet spoke-prod-back
az network vnet create -g $rg -l $location --name $vnet_spoke_prod_back_name --address-prefix $vnet_spk_p_b_ip
#Récupérer l'ID :
id_vnet_spoke_prod_back=$(az network vnet show --name $vnet_spoke_prod_back_name -g $rg --query id -o tsv)


#  subnet   #
#------------

#wordpress
az network vnet subnet create -g $rg --vnet-name $vnet_spoke_prod_front_name -n $subnet_spoke_prod_front_wordpress_name --address-prefixes $sub_spk_p_f_wp_ip
#db-wordpress
az network vnet subnet create -g $rg --vnet-name $vnet_spoke_prod_back_name -n $subnet_spoke_prod_back_dbwordpress_name --address-prefixes $sub_spk_p_b_dbwp_ip


# Création Peering :
#Hub_To_Prod_Front_Spoke
az network vnet peering create -g $rg -n HubToSpokeProdFront --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_prod_front_name --allow-vnet-access
#Hub_To_Prod_Back_Spoke
az network vnet peering create -g $rg -n HubToSpokeProdBack --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_prod_back_name --allow-vnet-access

#Prod_Front_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdFrontToHub --vnet-name $vnet_spoke_prod_front_name --remote-vnet $vnet_hub_name --allow-vnet-access
#Prod_Back_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdBackToHub --vnet-name $vnet_spoke_prod_back_name --remote-vnet $vnet_hub_name --allow-vnet-access




######################
# KeyVault 
######################


#Azure Keyvault
az keyvault create --name $name_vault_prod --resource-group $rg --location $location   --enable-rbac-authorization false

#Ajouter un secret pour le login de la VM :
az keyvault secret set --vault-name $name_vault_prod --name "AdminPassword" --value "Motdepasse123!"
az keyvault secret set --vault-name $name_vault_prod --name DBPassword --value "Motdepasse123!"
az keyvault secret set --vault-name $name_vault_prod --name DBUser --value "wpuser"
az keyvault secret set --vault-name $name_vault_prod --name DBName --value "wordpress"




########################################
#VM
########################################

# Public_IP's #
#--------------
# Public IP Bstion
az network public-ip create -g $rg -l $location -n $name_ip_pub_bastion --sku Standard

# Public IP Load Balancer Front
az network public-ip create -g $rg -l $location -n $name_ip_pub_lb_prod_front --sku Standard

# Public IP VM Temporaire
az network public-ip create -g $rg -l $location -n $name_ip_pub_vm_wp_front_temp --sku Standard


# Nic's #
#--------
#NIC VM Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_front_wp_client1 --vnet-name $vnet_spoke_prod_front_name --subnet $subnet_spoke_prod_front_wordpress_name --public-ip-address $name_ip_pub_vm_wp_front_temp

#NIC VM DB-Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_back_dbwp_client1 --vnet-name $vnet_spoke_prod_back_name --subnet $subnet_spoke_prod_back_dbwordpress_name
ip_vm_prod_back_dbwp=$(az network nic show   --g $rg   --name $name_nic_prod_back_dbwp_client1  --query "ipConfigurations[0].privateIPAddress"   -o tsv)

export WP_DB_NAME="wordpress"
export WP_DB_USER="wpuser"
export WP_DB_PASS="Motdepasse123!"
export WP_DB_HOST=$ip_vm_prod_back_dbwp
# VM's #
#-------

#VM Wordpress Front

az vm create \
  --resource-group $rg \
  --location $location \
  --name $name_vm_prod_front_wp_client1 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics $name_nic_prod_front_wp_client1 \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --custom-data <(envsubst < wp-cloud-init.yaml) \
  --zone 1

#VM DB Wordpress Back
az vm create \
  --resource-group $rg \
  --location $location \
  --name $name_vm_prod_back_dbwp_client1 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics $name_nic_prod_back_dbwp_client1 \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --custom-data dbwp-cloud-init.txt\
  --zone 1



########################################
#   NSG & ASG
########################################

##################### NSG Front Web
az network nsg create \
  --name $name_nsg_prod_front \
  --resource-group $rg \
  --location $location

az network nic update \
  --resource-group $rg \
  --name $name_nic_prod_front_wp_client1 \
  --network-security-group $name_nsg_prod_front



az network nsg rule create \
  --resource-group $rg \
  --nsg-name $name_nsg_prod_front \
  --name AllowSSHToSubnet \
  --priority 155 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-address-prefixes $name_ip_pub_vm_wp_front_temp \
  --destination-port-ranges 80



##################### NSG Front Web
az network nsg create \
  --name $name_nsg_prod_back \
  --resource-group $rg \
  --location $location


az network nsg rule create \
  --resource-group $rg \
  --nsg-name $name_nsg_prod_back \
  --name AllowMySQL \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --destination-asgs "*"\
  --destination-port-ranges 3306


########################################
#   Création de Bastion 
########################################

az network vnet subnet create --resource-group $rg \
															--vnet-name $vnet_hub_name \
															--name AzureBastionSubnet \
															--address-prefix $bastion_hub_subnet

az network bastion create --resource-group $rg \
													--location $location \
													--name bastion \
													--public-ip-address $name_ip_pub_bastion \
									        --sku Standard \
													--vnet-name $vnet_hub_name \
													--no-wait	


#Firewall




#############
#
#############

az identity create --resource-group $rg --name wordpress-identity

principalId_wp_managedId=$(az identity show --resource-group $rg --name wordpress-identity --query "principalId" -o tsv)

az keyvault set-policy --name $name_vault_prod \
      --object-id $principalId_wp_managedId \
      --secret-permissions get list


az vm identity assign --name $name_vm_prod_front_wp_client1 --resource-group $rg
az vm identity assign --name $name_vm_prod_back_dbwp_client1 --resource-group $rg

az keyvault set-policy --name MonKeyVault \
  --object-id <ID_VM> \
  --secret-permissions get


########################################
#   Storage Account
########################################

# strg-prod

# blob

#fileshare NFS















########Template Bicep VM#########



