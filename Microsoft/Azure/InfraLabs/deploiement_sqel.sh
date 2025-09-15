#Sinon déclarer le nom içi :
rg="prod-dev"
location="eastus"

#Spéciale Pluralsight
rg=$(az group list --query "[].name" --output tsv)
location="eastus"

#Variables
#---------

#Nom des vnets
name_vnet_hub="vnet_hub"

name_vnet_spoke_prod_front="vnet_spoke_prod_front"
name_vnet_spoke_prod_back="vnet_spoke_prod_back"

name_vnet_spoke_staging_front="vnet_spoke_staging_front"
name_vnet_spoke_staging_back="vnet_spoke_staging_back"

name_vnet_spoke_dev_front="vnet_spoke_dev_front"
name_vnet_spoke_dev_back="vnet_spoke_dev_back"

#Nom des subnets :
name_subnet_hub="vnet_hub"

name_subnet_spoke_prod_front_wordpress="prod_front_wordpress"
name_subnet_spoke_prod_back_wordpress="prod_back_wordpress"

name_subnet_spoke_staging_front_wordpress="staging_front_wordpress"
name_subnet_spoke_staging_back_wordpress="staging_back_wordpress"

name_subnet_spoke_dev_front_wordpress="dev_front_wordpress"
name_subnet_spoke_dev_back_wordpress="ev_back_wordpress"

#Addressage Hub :
adr_vnet_hub="10.0.0.0/16"
adr_subnet_hub="10.0.1.0/24"
adr_subnet_fw_hub="10.0.2.0/26"
adr_subnet_fw_hub_mgmt="10.0.2.64/26"
adr_subnet_bastion="10.0.2.128/26"
adr_subnet_vpn_gateway="10.0.2.192/26"

#Addressage Vnets Spoke :
adr_vnet_spoke_prod_front="10.1.0.0/16"
adr_vnet_spoke_prod_back="10.100.0.0/16"

adr_vnet_spoke_staging_front="10.30.0.0/16"
adr_vnet_spoke_staging_back="10.130.0.0/16"

adr_vnet_spoke_dev_front="10.60.0.0/16"
adr_vnet_spoke_dev_back="10.160.0.0/16"

#Adressage Subnets :

adr_subnet_spoke_prod_front_wordpress="10.1.1.0/24"
adr_subnet_spoke_prod_back_wordpress="10.100.1.0/24"

adr_subnet_spoke_staging_front_wordpress="10.30.1.0/24"
adr_subnet_spoke_staging_back_wordpress="10.130.1.0/24"

adr_subnet_spoke_dev_front_wordpress="10.60.1.0/24"
adr_subnet_spoke_dev_back_wordpress="10.160.1.0/24"


#Nom des interfaces réseaux :
name_nic_prod_front_clientA_wp_01="p_f_clientA_wp_01"
name_nic_prod_back_clientA_dbwp_01="p_b_clientA_dbwp_01"

#nom des vaults :
name_vault_prod="p-edulabsVault-2"
name_vault_staging="s-edulabsVault-2"
name_vault_dev="d-edulabsVault-2"


#Noms des IP publique :
name_ip_pub_bastion="ip_pub_bastion"
name_ip_pub_vm_wp_front_temp="ip_pub_vm_temp"
name_ip_pub_fw_hub="ip_fw_hub"
name_ip_pub_fw_mgmt_hub="ip_fw_mgmt_hub"
name_ip_pub_lb_prod_front="ip_pub_lb_prod_front"
name_ip_pub_vpn="ip_pub_vpn"

#Noms des VM
name_vm_prod_front_clientA_wp_01="prod_front_wp_clientA"
name_vm_prod_back_clientA_dbwp_01="prod_back_dbwp_clientA"


#Noms des NSG
name_nsg_prod_front="nsg-prod-front"
name_nsg_prod_back="nsg-prod-back"


#Noms des services Hub :
name_fw_hub="fw_hub"
name_lb_hub="lb_interne"

#Route Tables
name_udr_prod_front_wordpress="RT-Prod-Front-Hub-WP"
name_udr_prod_back_wordpress="RT-Prod-Back-Hub-WP"




###################################################
# VNET & SUBNET
###################################################

#  VNet   #
#------------

#Création du Vnet hub
az network vnet create  -g $rg \
                        -l $location \
                        --name $name_vnet_hub \
                        --address-prefix $adr_vnet_hub \
                        --subnet-name $name_subnet_hub \
                        --subnet-prefixes $adr_subnet_hub

id_vnet_hub=$(az network vnet show --name $name_vnet_hub -g $rg --query id -o tsv)


#Création du VNet Spoke Prod Front
az network vnet create  -g $rg \
                        -l $location \
                        --name $name_vnet_spoke_prod_front \
                        --address-prefix $adr_vnet_spoke_prod_front

id_vnet_spoke_prod_front=$(az network vnet show --name $name_vnet_spoke_prod_front -g $rg --query id -o tsv)



#Création du VNet Spoke Prod Back
az network vnet create  -g $rg \
                        -l $location \
                        --name $name_vnet_spoke_prod_back \
                        --address-prefix $adr_vnet_spoke_prod_back

id_vnet_spoke_prod_back=$(az network vnet show --name $name_vnet_spoke_prod_back -g $rg --query id -o tsv)


#  Subnet  #
#-----------

#Subnet du Wordpress prod front
az network vnet subnet create -g $rg \
                              --vnet-name $name_vnet_spoke_prod_front \
                              -n $name_subnet_spoke_prod_front_wordpress \
                              --address-prefixes $adr_subnet_spoke_prod_front_wordpress

#Subnet du Wordpress prod back
az network vnet subnet create -g $rg \
                              --vnet-name $name_vnet_spoke_prod_back \
                              -n $name_subnet_spoke_prod_back_wordpress \
                              --address-prefixes $adr_subnet_spoke_prod_back_wordpress


#Création du peering entre les spokes et le hub :
#Hub_To_Prod_Front_Spoke
az network vnet peering create -g $rg \
                              -n HubToProdFront \
                              --vnet-name $name_vnet_hub \
                              --remote-vnet $name_vnet_spoke_prod_front \
                              --allow-vnet-access \
                              --allow-forwarded-traffic true

#Hub_To_Prod_Back_Spoke
az network vnet peering create -g $rg \
                              -n HubToProdBack \
                              --vnet-name $name_vnet_hub \
                              --remote-vnet $name_vnet_spoke_prod_back \
                              --allow-vnet-access \
                              --allow-forwarded-traffic true                              

#Front_Prod_To_Hub
az network vnet peering create -g $rg \
                              -n FrontProdToHub \
                              --vnet-name $name_vnet_spoke_prod_front \
                              --remote-vnet $name_vnet_hub \
                              --allow-vnet-access \
                              --allow-forwarded-traffic true
#Back_Prod_To_Hub
az network vnet peering create -g $rg \
                              -n BackProdToHub \
                              --vnet-name $name_vnet_spoke_prod_back \
                              --remote-vnet $name_vnet_hub \
                              --allow-vnet-access \
                              --allow-forwarded-traffic true                                


######################
# Public_IP's #
######################


# Public IP Bstion
az network public-ip create -g $rg -l $location \
                            -n $name_ip_pub_bastion \
                            --sku Standard

# Public IP Load Balancer Front
az network public-ip create -g $rg -l $location \
                            -n $name_ip_pub_lb_prod_front \
                            --sku Standard

# Public IP VM Temporaire
az network public-ip create -g $rg -l $location \
                            -n $name_ip_pub_vm_wp_front_temp \
                            --sku Standard

# Public IP Firewall Hub
az network public-ip create -g $rg -l $location \
                            -n $name_ip_pub_fw_hub \
                            --sku Standard \
                            --zone 1 2 3

# Public IP Firewall Hub
az network public-ip create -g $rg -l $location \
                            -n $name_ip_pub_fw_mgmt_hub \
                            --sku Standard \
                            --zone 1 2 3

########################################
#   Création de Bastion 
########################################

az config set extension.use_dynamic_install=yes_without_prompt

az network vnet subnet create --resource-group $rg \
															--vnet-name $name_vnet_hub \
															--name AzureBastionSubnet \
															--address-prefix $adr_subnet_bastion

az network bastion create --resource-group $rg \
													--location $location \
													--name bastion \
													--public-ip-address $name_ip_pub_bastion \
									        --sku Standard \
													--vnet-name $name_vnet_hub \
													--no-wait	


########################################
#   Firewall
########################################

az network vnet subnet create -g $rg \
            --vnet-name $name_vnet_hub \
            -n AzureFirewallSubnet \
            --address-prefixes $adr_subnet_fw_hub

az network vnet subnet create -g $rg \
            --vnet-name $name_vnet_hub \
            -n AzureFirewallManagementSubnet \
            --address-prefixes $adr_subnet_fw_hub_mgmt



#Création du Firewall Manuellement
# 1. New Policy  : fw_hub_policy - Tier : Basic 
# 2. Choose existing Vnet + subnet
# 3. Choose Management public IP address
# 4. Create 
# 5. Add : rule Collection > Network Rules on Policy 
# 6. Autorise IP source > IP destiniation et vice versa
# 7. 


#Récupérer l'ip privée du firewall :
ip_fw_hub_private=$(az network firewall show \
  --name fw_hub \
  --resource-group $rg \
  --query "ipConfigurations[0].privateIPAddress" \
  --output tsv)


########################################
#   Azure Application Gateway
########################################
#Création IP Publique pour la gateway ip_pub_appgw_prod
#Création d'un subnet pour la gateway 10.0.2.192/26
#Tier Standard
#FrontEnd > ip public
#Enable Autoscaling 1 -2
#IPv4 Only
#Backend PiP ip_pub_appgw_prod + Private IP (10.0.2.100)
#Backend Pool : Nom prod_wp_clientA   > IP VM
#Backend settings : prod_WP_clientA > Port "80" > Dedicated Backend Connection
#Ajouter Rules "Prod_WP_ClientA" > Listner "prod_wp_clientA" >  BAckend targer "prod_wp_clientA" > backend settings "prod_wp_clientA" > Priority 100
#Listner  "prod_wp_clientA" > Rule "Prod_WP_ClientA" > Port "80" > Protocol "HTTP" > Listner Type : MultiSite > Host type : Single Hostname "Nom de domaine" > 


#Ajouter une règle au firewall pour autoriser le traffic vers l'AppGateway



######################
# KeyVault 
######################

#Azure Keyvault
az keyvault create --name $name_vault_prod \
                   -g $rg \
                   -l $location \
                   --enable-rbac-authorization false

#Ajouter un secret pour le login de la VM :
az keyvault secret set --vault-name $name_vault_prod \
                       --name "AdminPassword" \
                       --value "Motdepasse123!"

#Ajouter des secrets pour la base de donnée et config wp :
az keyvault secret set --vault-name $name_vault_prod \
                       --name DBPassword \
                       --value "Motdepasse123!"

az keyvault secret set --vault-name $name_vault_prod \
                       --name DBUser \
                       --value "wpuser"
                       
az keyvault secret set --vault-name $name_vault_prod \
                       --name DBName \
                       --value "wordpress"


######################
# NIC
######################
#NIC VM Wordpress ClientA
az network nic create -g $rg -l $location \
                      -n $name_nic_prod_front_clientA_wp_01 \
                      --vnet-name $name_vnet_spoke_prod_front \
                      --subnet $name_subnet_spoke_prod_front_wordpress \
                      --public-ip-address $name_ip_pub_vm_wp_front_temp

ip_vm_front_public_temp=$(az network nic show \
                      -n $name_nic_prod_front_clientA_wp_01 \
                      -g $rg \
                      --query "ipConfigurations[0].publicIPAddress.id" \
                      -o tsv | xargs az network public-ip show --ids | jq -r '.ipAddress')


#NIC VM Base de donnée Wordpress ClientA
az network nic create -g $rg -l $location \
                      -n $name_nic_prod_back_clientA_dbwp_01 \
                      --vnet-name $name_vnet_spoke_prod_back \
                      --subnet $name_subnet_spoke_prod_back_wordpress 

ip_vm_prod_back_dbwp=$(az network nic show \
                      -n $name_nic_prod_back_clientA_dbwp_01 \
                      -g $rg \
                      --query "ipConfigurations[0].privateIPAddress" \
                      -o tsv)


######################
# Machines Virtuelles
######################

#VM Wordpress Front

az vm create \
  --resource-group $rg \
  --location $location \
  --name $name_vm_prod_front_clientA_wp_01 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics $name_nic_prod_front_clientA_wp_01 \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --custom-data wp-cloud-init.yaml \
  --zone 1

#Récupérer son IP


#VM DB Wordpress Back
az vm create \
  --resource-group $rg \
  --location $location \
  --name $name_vm_prod_back_clientA_dbwp_01 \
  --image Debian:debian-11:11:latest \
  --size Standard_B1ms \
  --admin-username "lotfi" \
  --admin-password "Motdepasse123!" \
  --nics $name_nic_prod_back_clientA_dbwp_01 \
  --os-disk-delete-option Delete \
  --storage-sku Premium_LRS \
  --custom-data dbwp-cloud-init.yaml\
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
  --name $name_nic_prod_front_clientA_wp_01 \
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
  --destination-address-prefixes $adr_subnet_spoke_prod_front_wordpress \
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



########################################
#   UDR
########################################



az network route-table create \
  --name $name_udr_prod_front_wordpress \
  --resource-group $rg \
  --location $location

az network vnet subnet update \
  --resource-group $rg \
  --vnet-name $name_vnet_spoke_prod_front \
  --name $name_subnet_spoke_prod_front_wordpress \
  --route-table $name_udr_prod_front_wordpress

az network route-table route create \
  --resource-group $rg \
  --route-table-name $name_udr_prod_front_wordpress \
  --name RouteToBack \
  --address-prefix $adr_subnet_spoke_prod_back_wordpress \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $ip_fw_hub_private

az network route-table create \
  --name $name_udr_prod_back_wordpress \
  --resource-group $rg \
  --location $location

az network vnet subnet update \
  --resource-group $rg \
  --vnet-name $name_vnet_spoke_prod_back \
  --name $name_subnet_spoke_prod_back_wordpress \
  --route-table $name_udr_prod_back_wordpress

az network route-table route create \
  --resource-group $rg \
  --route-table-name $name_udr_prod_back_wordpress \
  --name RouteToFront \
  --address-prefix $adr_subnet_spoke_prod_front_wordpress \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $ip_fw_hub_private


  
