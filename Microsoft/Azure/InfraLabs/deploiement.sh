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

vnet_spoke_prod_front_name="vnet_spk_p_f"
vnet_spk_p_f_ip="10.1.0.0/16"
subnet_spoke_prod_front_wordpress_name="sub_spk_p_f_wp"
sub_spk_p_f_wp_ip="10.1.1.0/24"

vnet_spoke_prod_back_name="vnet_spk_p_b"
vnet_spk_p_b_ip="10.2.0.0/16"
subnet_spoke_prod_back_dbwordpress_name="sub_spk_p_b_dbwp"
sub_spk_p_b_dbwp_ip="10.2.1.0/24"




name_nic_prod_front_wp_client1="wp_front_client1"
name_nic_prod_back_dbwp_client1="dbwp_back_client1"

name_vault_prod="edulabsVault-4"

name_ip_pub_bastion="ip-pub-bastion"
name_ip_pub_lb_prod_front="ip-pub-lb-prod-front"
name_ip_pub_vm_wp_front_temp="ip-pub-vm-temp"

name_vm_prod_front_wp_client1="wp-client01"
name_vm_prod_back_dbwp_client1="dbwp-client01"

name_nsg_prod_front="nsg-prod-front"
name_nsg_prod_back="nsg-prod-back"

bastion_hub_subnet="10.0.1.0/26"
fw_mgmt_hub_subnet="10.0.1.128/26"
fw_hub_subnet="10.0.1.64/26"


name_ip_pub_vm_fw_hub="ip_fw_hub"
name_ip_pub_vm_fw_mgmt_hub="ip_fw_mgmt_hub"

name_fw_hub="fw_hub"

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
az network vnet peering create -g $rg -n HubToSpokeProdFront --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_prod_front_name --allow-vnet-access --allow-forwarded-traffic true
#Hub_To_Prod_Back_Spoke
az network vnet peering create -g $rg -n HubToSpokeProdBack --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_prod_back_name --allow-vnet-access --allow-forwarded-traffic true

#Prod_Front_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdFrontToHub --vnet-name $vnet_spoke_prod_front_name --remote-vnet $vnet_hub_name --allow-vnet-access --allow-forwarded-traffic true
#Prod_Back_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdBackToHub --vnet-name $vnet_spoke_prod_back_name --remote-vnet $vnet_hub_name --allow-vnet-access --allow-forwarded-traffic true


# Peering temporaire à supprimer ensuite
######################

az network vnet peering create -g $rg -n SpokeProdFrontToSpokeBack --vnet-name $vnet_spoke_prod_front_name --remote-vnet $vnet_spoke_prod_back_name --allow-vnet-access
#Prod_Back_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdBackToSpokeFront --vnet-name $vnet_spoke_prod_back_name --remote-vnet $vnet_spoke_prod_front_name --allow-vnet-access


#Suppression des peering temporaire
az network vnet peering delete -g $rg --name SpokeProdFrontToSpokeBack --vnet-name $vnet_spoke_prod_front_name
az network vnet peering delete -g $rg --name SpokeProdBackToSpokeFront --vnet-name $vnet_spoke_prod_back_name


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

# Public IP Firewall Hub
az network public-ip create -g $rg -l $location -n $name_ip_pub_vm_fw_hub --sku Standard --zone 1 2 3

# Public IP Firewall Hub
az network public-ip create -g $rg -l $location -n $name_ip_pub_vm_fw_mgmt_hub --sku Standard --zone 1 2 3

########################################
#   Création de Bastion 
########################################

az config set extension.use_dynamic_install=yes_without_prompt

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


# Nic's #
#--------
#NIC VM Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_front_wp_client1 --vnet-name $vnet_spoke_prod_front_name --subnet $subnet_spoke_prod_front_wordpress_name --public-ip-address $name_ip_pub_vm_wp_front_temp

ip_vm_front_public_temp=$(az network nic show \
  --name $name_nic_prod_front_wp_client1 \
  --resource-group $rg \
  --query "ipConfigurations[0].publicIPAddress.id" \
  --output tsv | xargs az network public-ip show --ids | jq -r '.ipAddress')

#NIC VM DB-Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_back_dbwp_client1 --vnet-name $vnet_spoke_prod_back_name --subnet $subnet_spoke_prod_back_dbwordpress_name
ip_vm_prod_back_dbwp=$(az network nic show -g $rg --name $name_nic_prod_back_dbwp_client1  --query "ipConfigurations[0].privateIPAddress" -o tsv)



#### DB Variables
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
  --custom-data wp-cloud-init.yaml \
  --zone 1

#Récupérer son IP


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
  --custom-data dbwp-cloud-init.yaml\
  --zone 1

#Récupérer son IP


###ATTENTION SUPPRESSION SI JAMAIS CA NE FONCTIONNE PAS (POUR REFAIRE)
az vm delete -g $rg -n $name_vm_prod_back_dbwp_client1 --force-deletion


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
  --name AllowHTTPToSubnet \
  --priority 155 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-address-prefixes $ip_vm_front_public_temp \
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
  --destination-address-prefixes "*"\
  --destination-port-ranges 3306



#Commande astuces :
nc -zv <ip> 3306
mysql -h 10.2.1.4 -u root -p


###############
# Private DNS #
###############
Ajouter un Link au 3 Vnet avec auto registration.


########################################
#   Firewall

#2 x IP sku standard, Zone redundant 
#basic
#Create Firewall Policy
#Create Rule Collection groups
#Définir 2 règles :
#- Front to back
#- Back to front
########################################


#En Commun :

az network vnet subnet create -g $rg \
            --vnet-name $vnet_hub_name \
            -n AzureFirewallSubnet \
            --address-prefixes $fw_hub_subnet

az network vnet subnet create -g $rg \
            --vnet-name $vnet_hub_name \
            -n AzureFirewallManagementSubnet \
            --address-prefixes $fw_mgmt_hub_subnet

#Création d'une policy
az network firewall policy create \
  --name fw_hub_policy \
  --resource-group $rg \
  --location $location \
  -tier Basic \
  --threat-intel-mode Alert

az network firewall policy rule-collection-group create \
  --policy-name fw_hub_policy \
  --resource-group $rg \
  --name WordpressCollectionRuleGroup \
  --priority 100 \
  --rule-collection @firewall_prod_wp_rules.json


################
# En mode Bicep
#######
az deployment group create \
  --name DeployFirewall \
  --resource-group $rg \
  --template-file firewall.bicep \
  --parameters \
    subscriptionId=$(az account show --query id -o tsv) \
    resourceGroup=$rg \
    location=$location \
    azureFirewallName=$name_fw_hub \
    vnetName=$vnet_hub_name \
    mgmtPublicIpName=$name_ip_pub_vm_fw_mgmt_hub \
    firewallPolicyName=fw_hub_policy



################
# En mode CLI
#######

# Créer le Firewall
az network firewall create \
  --resource-group $rg \
  --name $name_fw_hub \
  --location $location \
  --sku AZFW_VNet \
  --tier Basic \
  --zones 1 2 3 \
  --firewall-policy fw_hub_policy

# Associer la configuration IP
az network firewall ip-config create \
  --firewall-name $name_fw_hub \
  --resource-group $rg \
  --name fw-ipconf \
  --vnet-name $vnet_hub_name \
  --subnet AzureFirewallSubnet

# Ajouter la configuration de management
az network firewall management-ip-config create \
  --firewall-name $fw \
  --resource-group $rg \
  --name mgmt-ipconf \
  --public-ip-address $ip_fw_mgmt_hub \
  --vnet-name $vnet_hub_name \
  --subnet AzureFirewallManagementSubnet



#Récupération de l'IP privée du firewall (qui servira pour les UDR)
ip_fw_hub_private=$(az network firewall show \
  --name fw_hub \
  --resource-group $rg \
  --query "ipConfigurations[0].privateIPAddress" \
  --output tsv)




########################################
#   UDR
########################################

###### Front to back

az network route-table create \
  --name RT-Front-Hub \
  --resource-group $rg \
  --location $location

az network vnet subnet update \
  --resource-group $rg \
  --vnet-name $vnet_spoke_prod_front_name \
  --name $subnet_spoke_prod_front_wordpress_name \
  --route-table RT-Front-Hub


az network route-table route create \
  --resource-group $rg \
  --route-table-name RT-Front-Hub \
  --name RouteToBack \
  --address-prefix 10.2.1.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $ip_fw_hub_private



######Back To Front

az network route-table create \
  --name RT-Back-Hub \
  --resource-group $rg \
  --location $location

az network vnet subnet update \
  --resource-group $rg \
  --vnet-name $vnet_spoke_prod_back_name \
  --name $subnet_spoke_prod_back_dbwordpress_name \
  --route-table RT-Back-Hub


az network route-table route create \
  --resource-group $rg \
  --route-table-name RT-Back-Hub \
  --name RouteToFront \
  --address-prefix 10.1.1.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $ip_fw_hub_private












####################
# IDENTITY MANAGED #
####################

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

az storage account create \
  --name nomducompte \
  --resource-group nomdugroupe \
  --location westeurope \
  --sku Standard_LRS \
  --kind StorageV2



# strg-prod

# blob

#fileshare NFS





######## Staging #########

vnet_spoke_stag_front_name="vnet_spk_s_f"
vnet_spk_s_f_ip="10.10.0.0/16"
subnet_spoke_stag_front_wordpress_name="sub_spk_s_b_dbwp"
sub_spk_s_wp_ip="10.10.1.0/24"

vnet_spoke_stag_back_name="vnet_spk_s_b"
vnet_spk_s_b_ip="10.11.0.0/16"
subnet_spoke_stag_back_dbwordpress_name="sub_spk_s_b_dbwp"
sub_spk_s_b_dbwp_ip="10.11.1.0/24"


#wordpress
az network vnet subnet create -g $rg --vnet-name $vnet_spoke_stag_front_name -n $subnet_spoke_stag_front_wordpress_name --address-prefixes $sub_spk_s_f_wp_ip
#db-wordpress
az network vnet subnet create -g $rg --vnet-name $vnet_spoke_stag_back_name -n $subnet_spoke_stag_back_dbwordpress_name --address-prefixes $sub_spk_s_b_dbwp_ip


# Création Peering :
Hub_To_Prod_Front_Spoke
az network vnet peering create -g $rg -n HubToSpokeProdFront --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_stag_front_name --allow-vnet-access
#Hub_To_Prod_Back_Spoke
az network vnet peering create -g $rg -n HubToSpokeProdBack --vnet-name $vnet_hub_name --remote-vnet $vnet_spoke_stag_back_name --allow-vnet-access

#Prod_Front_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdFrontToHub --vnet-name $vnet_spoke_stag_front_name --remote-vnet $vnet_hub_name --allow-vnet-access
#Prod_Back_Spoke_To_Hub
az network vnet peering create -g $rg -n SpokeProdBackToHub --vnet-name $vnet_spoke_stag_back_name --remote-vnet $vnet_hub_name --allow-vnet-access


