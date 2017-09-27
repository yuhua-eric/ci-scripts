#install ansible
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible

git clone https://github.com/open-estuary/ci-scripts.git -b openlab2.0
cd ci-scripts/deploy-script/kernelci/kerenelci-backend-config/

ansible-playbook -i hosts site.yml --skip-tags=backup,firewall,web-server --ask-pass --ask-sudo-pass

#change the default token
curl -X POST -H "Content-Type: application/json" -H "Authorization: 123456" -d '{"email": "you@example.net", "admin": 1}' 120.31.149.194:8888/token

#save the above token into the frontend host_vars backend_token
echo "Please use the above token in the frontend host_vars as the backend_token!"

#set upload url and token
sudo cp buildpy.cfg /var/lib/jenkins/.buildpy.cfg
sudo chown -vR jenkins:jenkins /var/lib/jenkins/.buildpy.cfg
