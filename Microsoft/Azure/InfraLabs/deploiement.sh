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




name_vault_prod="edulabsVault"


#Azure Keyvault
az keyvault create --name $name_vault_prod --resource-group $rg --location $location

#Ajouter un secret pour le login de la VM :
az keyvault secret set --vault-name $name_vault_prod --name "AdminPassword" --value "Motdepasse123!"




########################################
#VM
########################################


name_ip_pub_bastion="ip-pub-bastion"
name_ip_pub_lb_prod_front="ip-pub-lb-prod-front"
name_ip_pub_vm_wp_front_temp="ip-pub-vm-temp"

# Public_IP's #
#--------------
# Public IP Bstion
az network public-ip create -g $rg -l $location -n $name_ip_pub_bastion

# Public IP Load Balancer Front
az network public-ip create -g $rg -l $location -n $name_ip_pub_lb_prod_front

# Public IP VM Temporaire
az network public-ip create -g $rg -l $location -n $name_ip_pub_vm_wp_front_temp




name_nic_prod_front_wp_client1="wp_front_client1"
name_nic_prod_front_dbwp_client1="dbwp_back_client1"


# Nic's #
#--------
#NIC VM Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_front_wp_client1 --vnet-name spoke-prod-front --subnet wordpress --public-ip-address ip-pub-wp-clt1

#NIC VM DB-Wordpress Client 1
az network nic create -g $rg -l $location -n $name_nic_prod_front_dbwp_client1 --vnet-name spoke-prod-back --subnet db-wordpress



vm-prod-front-client1="vm-prod-front-client1"

# VM's #
#-------

#VM Wordpress Front

az vm create \
  --resource-group $rg \
  --location $location \
  --name vm-prod-front-client1 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics "nic-vm-prod-front-wp-clt1" \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --zone 1


#VM DB Wordpress Back
az vm create \
  --resource-group $rg \
  --location $location \
  --name vm-prod-back-client1 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics "nic-vm-prod-back-wp-clt1" \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --zone 1


# Attaching NIC to VM #
#----------------------




########################################
#   NSG & ASG
########################################


#ASG Front Wordpress Client1
az network asg create \
  --name asg1-wordpress-client1 \
  --resource-group $rg\
  --location $location

nic_wp_prod_ctl1_conf=$(az network nic show --name nic-vm-prod-front-wp-clt1 --resource-group $rg --query "ipConfigurations[].name" --output tsv)

az network nic ip-config update \
  --name $nic_wp_prod_ctl1_conf \
  --nic-name nic-vm-prod-front-wp-clt1 \
  --resource-group $rg \
  --application-security-groups asg1-wordpress-client1


#ASG Back Wordpress Client1
az network asg create \
  --name asg1-db-wp-client1 \
  --resource-group $rg\
  --location $location

nic_wp_back_ctl1_conf=$(az network nic show --name nic-vm-prod-back-wp-clt1 --resource-group $rg --query "ipConfigurations[].name" --output tsv)

az network nic ip-config update \
  --name $nic_wp_back_ctl1_conf \
  --nic-name nic-vm-prod-back-wp-clt1 \
  --resource-group $rg \
  --application-security-groups asg1-db-wp-client1



##################### NSG Front Web
az network nsg create \
  --name nsg-front-prod \
  --resource-group $rg \
  --location $location

# NSG Rule Back Wordpress

az network nsg rule create \
  --resource-group $rg \
  --nsg-name nsg-front-prod \
  --name AllowSSH \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-asgs asg1-wordpress-client1 \
  --destination-port-ranges 22

az network nsg rule create \
  --resource-group $rg \
  --nsg-name nsg-front-prod \
  --name AllowHTTP \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-asgs asg1-wordpress-client1 \
  --destination-port-ranges 80


##################### NSG Front Web
az network nsg create \
  --name nsg-back-prod \
  --resource-group $rg \
  --location $location

# NSG Rule Back Wordpress

az network nsg rule create \
  --resource-group $rg \
  --nsg-name nsg-back-prod \
  --name AllowSSH \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --destination-asgs asg1-db-wp-client1 \
  --destination-port-ranges 22


az network nsg rule create \
  --resource-group $rg \
  --nsg-name nsg-back-prod \
  --name AllowMySQL \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --destination-asgs asg1-db-wp-client1 \
  --destination-port-ranges 3306


#Associé NSG a



#Firewall



########################################
#   Storage Account
########################################

# strg-prod

# blob

#fileshare NFS















########Template Bicep VM#########



