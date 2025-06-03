
Module Loading: Automatically loads specified R and Python modules, providing access to necessary software stacks.
Prerequisites
Access to an HPC cluster with Slurm and Singularity installed.
The RStudio Server Singularity image must be available at the path specified by the RSERVER_SIF environment variable (typically set by loading an RServer module, e.g., module load R/RServer/4.4.2).
The R/RServer/4.4.2 and Python3/3.8.0 modules (or equivalent versions) must be available on your cluster.
An SSH client on your local machine for tunneling.
How to Use
Configure the Script (run_rstudio.sh):

Slurm Directives: Adjust the #SBATCH parameters at the top of the script (--time, --cpus-per-task, --mem, --partition) to match your computational needs and your cluster's policies.
Home Directory: Verify or adjust the export HOME=/ampha/tenant/group01/private/user/$USER/ line if your user home directory structure differs.
RStudio Project Directory: If you prefer a different persistent directory for your RStudio projects than $HOME/RStudio_Projects, modify the HOST_RSTUDIO_DIR variable.
Submit the Job:

BASH
sbatch run_rstudio.sh
Retrieve Connection Information:

After the job starts, monitor the Slurm output file (e.g., rstudio-server.job.JOBID.out).
The script will print detailed connection instructions, including the compute node's hostname, the dynamically assigned port, your username, and the randomly generated password.
Example output:

TEXT
===============================================================
RStudio Server is starting on node: your_compute_node.example.com
===============================================================

To connect to RStudio Server:

1. On your local machine, open a new terminal and create an SSH tunnel:

   ssh -N -L 8787:your_compute_node.example.com:12345 your_username@hpc_login_node_ip

   (Replace 'hpc_login_node_ip' with your cluster's login node address)

2. Then, open your web browser and go to: http://localhost:8787

3. Log in to RStudio Server using these credentials:

   User:     your_username
   Password: your_generated_password

When you are done with RStudio Server:

1. In the RStudio window, click the "power" button (top right corner) to exit the RStudio Session.
2. On the HPC login node, terminate this Slurm job:

   scancel -f JOBID

===============================================================
Script will now wait for RStudio Server to terminate...
===============================================================
Create an SSH Tunnel (on your local machine):

Open a new terminal on your local computer.
Execute the ssh -N -L ... command provided in the Slurm output.
Important: Replace hpc_login_node_ip with the actual IP address or hostname of your cluster's login node.
Connect to RStudio Server (in your web browser):

Open your web browser and navigate to http://localhost:8787.
Enter the User and Password provided in the Slurm output to log in.
Important Considerations
Data Persistence:
Persistent: Files saved within the RStudio_Projects directory (or your custom HOST_RSTUDIO_DIR) will persist across job submissions, as this directory is directly mounted from your home directory.
Non-Persistent: RStudio Server's internal session data, temporary files, and any changes made outside the mounted RStudio_Projects directory (e.g., in /tmp or /var/lib/rstudio-server within the container) will not persist after the job ends. Each new job starts with a clean RStudio Server internal state.
R Package Management:
Thanks to the custom rsession.sh and R_LIBS_USER configuration, R packages installed via install.packages() will be saved to $HOME/R/rocker-rstudio/4.4.2 on the host system. This ensures that your installed packages persist between RStudio Server sessions.
Authentication: The randomly generated password is for the current RStudio Server session only. It is printed to your job's standard output file.
Job Termination: Always terminate your RStudio Server Slurm job using scancel -f JOBID from the HPC login node when you are finished. This ensures that resources are released promptly. While the script includes a trap mechanism, explicit scancel is the recommended way to end the job.
