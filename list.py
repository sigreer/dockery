from dotenv import load_dotenv
import paramiko
from prettytable import PrettyTable
import os

## Load environment variables from file
# Load environment variables from .env file
load_dotenv()
# SSH credentials and hosts
hosts = os.getenv('DOCKLIST_HOSTS', '').split(',')  # Replace with actual hostnames or IPs
ssh_user = os.getenv('DOCKLIST_SSH_USER')           # Replace with your SSH username
ssh_key_path = os.getenv('DOCKLIST_SSH_KEY_PATH')  # Replace with your SSH key path

# Command to find directories containing 'docker-compose.yml'
command = "sudo find /root/docker -type f -name 'docker-compose.yml'"

# Initialize table
table = PrettyTable()
table.field_names = ["Host", "App", "Category"]

# Function to extract app and category from the path
def extract_app_category(path):
    directory = os.path.dirname(path)
    app = os.path.basename(directory)
    category = os.path.basename(os.path.dirname(directory))
    return app, category

# Connect to each host and execute the command
for host in hosts:
    try:
        # Setup SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, username=ssh_user, key_filename=ssh_key_path)

        # Execute command
        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.readlines()

        # Process each line of output
        for line in output:
            app, category = extract_app_category(line.strip())
            table.add_row([host, app, category])

        # Close SSH connection
        ssh.close()

    except Exception as e:
        print(f"Error connecting to {host}: {e}")

# Print the table
print(table)
