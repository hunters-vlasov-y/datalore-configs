To install Datalore on-premise, first install and configure Hub, which provides a single point of entry for user management. The procedures below describe both stages of the process.

# 1. Install Hub
If you have already installed Hub, skip this part and go to the __Configuration of Hub__ section.
You can find more details about the Hub installation process [here](https://hub.docker.com/r/jetbrains/hub).
1. Run <!-- capitalized?-->Hub via command:
```
    kubectl apply -k <directory containing hub/hub-k8s.yaml>
```
2. (Here and elsewhere, we assume that you run the docker container on a local machine and choose port 8082 for port forwarding).
   Check the container output using the following command:
   ```
    kubectl logs service/hub
   ```
   It should contain a line like this:
   `JetBrains Hub 2020.1`. Configuration Wizard will listen inside the container on {0.0.0.0:8080}/
   after start and can be accessed by this URL:
  [http://<put-your-docker-HOST-name-here>:<put-host-port-mapped-to-container-port-8080-here>/?wizard_token=pPXTShp4NXceXqGYzeAq]`.
   Copy the token to the clipboard.
3. Go to `http://localhost:8082/` and insert the token from step __3__ into the __Token__ field. Click the __Log in__ button.
4. Click the __Set Up__ link.
5. In __Base URL__, specify the URL that you will use to access Hub (here, it is `http://localhost:8082/`). Don't change the __Application Listen Port__ setting.
6. Configure the admin account (set the admin password).
7. Finish the configuration process and wait for the Hub startup.
## 1.1 Configure Hub
Log into Hub via admin account.
### 1.1.1 Configure Datalore service
1. Go to Services (`http://localhost:8082/hub/services`) and click the __New service__ button. Use the name _datalore_ and your
   Datalore installation URL as __Home URL__.
2. Insert the Datalore installation URL into the __Base URLs__ field.
3. Insert line `/api/hub/openid/login` into the __Redirect URIs__ field.
4. Click the __Change...__ button near the __Secret__ label. Retain the generated secret somewhere – it will be used when configuring Datalore
   (`$HUB_DATALORE_SERVICE_SECRET` property). Click the __Change secret__ button.
5. Click the __Trust__ button in the upper-right corner.
6. Copy the `ID` field value – it is used when configuring Datalore (`$HUB_DATALORE_SERVICE_ID` property).
7. Click the __Save__ button.
### 1.1.2 Create Hub token
1. Go to Users (`http://localhost:8082/hub/users`).
2. Click your admin user's name.
3. Go to the `Authentication` tab.
4. Click the __New token...__ button.
5. Add Hub and Datalore into __Scope__. You can use any __Name__. Click the __Create__ button.
6. Remember the token. It will be used when configuring Datalore (`$HUB_PERM_TOKEN` property).
### 1.1.3 Force email verification
Datalore uses user emails from Hub, so it is recommended to force email verification in Hub.
Users with unverified emails will not be able to use Datalore.
#### 1.1.3.1 Configure SMTP server
1. Go to SMTP (`http://localhost:8082/hub/smtp-settings`).
2. Click the __Configure SMTP server...__ button.
3. Configure your SMTP server parameters.
4. Click the __Enable notifications__ button.
5. Click the __Save__ button.
5. (Optional) To make sure your configuration is working, click the __Send Test message__ button.
#### 1.1.3.2 Enable email verification
1. Go to Auth Modules (`http://localhost:8082/hub/authmodules`).
2. Open the __Common settings__ page.
3. Enable the __Email verification__ option.
4. Click the __Save__ button.
### 1.1.4 (Optional) Ban guest user
Skip this step if you need a guest user.
1. Go to Users (`http://localhost:8082/hub/users`).
2. Select a guest user.
3. Click the __Ban__ button.
### 1.1.5 (Optional) Enable auth modules
Go to Auth Modules (`http://localhost:8082/hub/authmodules`). Here, you can add/remove different auth modules
(e.g. Google auth, GitHub auth, LDAP, etc.).
# 2. Install Datalore
To run Datalore, you need Kubernetes (we have checked version `1.17.6`, but other versions should also work).
## 2.1 Configuration
To simplify the configuration process, the Kubernetes config is split into small chunks and assembled with 
the Kustomize tool (`-k` flag of `kubectl`).
Edit several files in the `configs` directory to configure your Datalore installation:
### 2.1.1 `user_config.yaml`
Editing this file is __mandatory__ to get everything working. The file has the following fields:
#### 2.1.1.1 Required parameters:
- `FRONTEND_URL` – URL by which Datalore can be accessed. It is used to generate links.  
  __Note:__ Make sure the URL does not contain a trailing slash.
- `HUB_BASE_URL` – root URL of your Hub installation (for this and the following, see the __Install Hub__ section). It should end with `/hub` (e.g. `https://your.domain/hub/`).
- `HUB_DATALORE_SERVICE_ID` – ID of the Datalore service in Hub (see __Configure Datalore service__ section).
- `HUB_DATALORE_SERVICE_SECRET` – token of the Datalore service in Hub (see the __Configure Datalore service__ section).
- `HUB_PERM_TOKEN` – Token for accessing Datalore and Hub scopes (see the __Create Hub token__ section).
  
- `DEFAULT_INSTANCE_TYPE_ID` — ID of the instance type that will be used by default (for more information, see `agents_config.yaml`).
- `PASSWORD_SECRET` – additional hash salt used to encrypt user passwords and prevent rainbow table attacks in case of a database leak. 
  Can be any string.
#### 2.1.1.2 Optional parameters:
  `MAIL_ENABLED` – set it to `"true"` in order to enable Datalore to send emails (welcome emails, sharing invitations, etc.). 
  When set to `"true"`, requires the following parameters:
  - `MAIL_SENDER_EMAIL` – sender's email.
  - `MAIL_SENDER_NAME` – sender's name.
  - `MAIL_SENDER_USERNAME` – username of SMTP user.
  - `MAIL_SENDER_PASSWORD` – password of SMTP user.
  - `MAIL_SMTP_SERVER` – SMTP server host.
  - `MAIL_SMTP_PORT` – SMTP server port.
### 2.1.2 `db_config.yaml`
This config file is used to configure MySQL connection from Datalore. There is one field to override:
- `MYSQL_ROOT_PASSWORD` – root user's password. The database can be accessed on port `3306` with the username `root` and this password.
### 2.1.3 `volumes_config.yaml`
This config file is used to mount volumes for persisting Datalore's data between restarts. If you leave the default configuration, you will __lose ALL DATA__ after the next Datalore restart. The config has two Kubernetes volumes described:
- `storage` – this volume contains workbook data, such as attached files.
- `mysql-data` – this volume contains MySQL database data.
### 2.1.4 `agents_config.yaml`
This config file is used to define agent types (such as Basic and Large machines in the cloud version of Datalore).
It has the following schema:
```yaml
k8s:
  instances:
    - id: <Inique instance ID>
      label: <Instance name>
      description: <Short description of what the instance is>
      minAllowed: <Minimum number of instances to be preserved in the pool>
      maxAllowed: <Maximum number of instances to be preserved in the pool>
      yaml:
        <Kubernetes config of Pod to be used for the instance>
    - id: <Another type with the same schema as above>
      ...
```
The `minAllowed` and `maxAllowed` fields are used to configure the number of pre-created instances, which will speed up the process of
starting up notebooks.  
__Note:__ Make sure that one of the IDs defined in the list of instances matches the `DEFAULT_INSTANCE_TYPE_ID` variable from `user_config.yaml`. That instance 
will be used as a default option when creating a notebook.
Besides changing the descriptive fields (all except `yaml`), you may want to customize the following pod description fields:  
- `spec -> containers -> image` – you can build a custom Docker image on top of the default one to customize your environment (i.e. install some
  package from `apt` to be available in your notebooks, or set up a custom Python environment by pre-installing the required libraries).
- `spec -> containers -> resources` – you can tune the resources required by the agent's pod to match your needs and capabilities.
### 2.1.5 `images_config.yaml`
This config file is used to define Datalore and MySQL container images. Most likely, you will need to change this only to update your installation
with <!--'never' presumably a typo--> newer versions of on-premises images.
### 2.1.6 `logback.xml`
This is the Logback configuration file that will be used to collect logs from Datalore and agents. We have provided the default one, which just prints them to `stdout`, but you can configure it any way you like.  
More information on how to configure Logback is available in [the official documentation](http://logback.qos.ch/manual/configuration.html).
## 2.2 Docker Hub token
Create a secret to pull images from a private repository:
`kubectl create secret docker-registry regcred --docker-username=datalorecustomer --docker-password=<datalore token>`
# 3. Run Datalore
## Start
`kubectl apply -k <directory containing base/k8s.yaml>`
## Stop
`kubectl delete -k <directory containing base/k8s.yaml>`
