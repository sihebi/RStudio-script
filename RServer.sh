#!/bin/sh
#SBATCH --job-name=RStudio_Server
#SBATCH --time=08:00:00        # 设置任务最长运行时间为8小时
#SBATCH --signal=USR2          # 用于向RStudio Server进程发送信号，但通常scancel更直接
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=24576            # 请求8GB内存
#SBATCH --partition=cpupart    # 添加 --partition 参数，指定使用 cpupart 分区
#SBATCH --output=rstudio-server.job.%j.out # 标准输出文件路径
#SBATCH --error=rstudio-server.job.%j.err  # 错误输出文件路径

# 添加 RSERVER_SIF 和Python 环境变量
# export RSERVER_SIF=/hpc/software/RStudio/RServer.sif
module load R/RServer/4.4.2
module load Python3/3.8.0
export HOME=/ampha/tenant/group01/private/user/$USER/

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
workdir=$(mktemp -d)
echo "Temporary working directory created: $workdir"

# ====================================================================
# 1. 加载RServer模块以获取SINGULARITY_IMAGE_PATH
# ====================================================================

# 检查RSERVER_SIF环境变量是否已设置
if [ -z "$RSERVER_SIF" ]; then
    echo "Error: RSERVER_SIF environment variable not set. Please load the RServer module (e.g., module load R/RServer/1.0)."
    exit 1
fi

# ====================================================================
# 2. 定义宿主机和容器内的RStudio项目目录
# ====================================================================
# 定义宿主机上要挂载的RStudio项目目录
HOST_RSTUDIO_DIR="$HOME/RStudio_Projects"
# 容器内RStudio Server的工作目录，这是用户在RStudio界面中看到和操作的目录
CONTAINER_MOUNT_POINT="/home/rstudio_user/RStudio_Projects" 

# 确保宿主机上的RStudio项目目录存在
mkdir -p "$HOST_RSTUDIO_DIR"
echo "Host RStudio project directory: $HOST_RSTUDIO_DIR"
echo "Container mount point: $CONTAINER_MOUNT_POINT"

# ====================================================================
# 3. 创建 rsession.sh 脚本并配置 R_LIBS_USER
# ====================================================================
# 创建 rsession.sh 脚本并写入到临时目录
cat > "${workdir}/rsession.sh" <<"END"
#!/bin/sh
# 设置 R_LIBS_USER 到一个用户家目录下 rocker-rstudio 专属的路径
export R_LIBS_USER="${HOME}/R/rocker-rstudio/4.4.2"
mkdir -p "${R_LIBS_USER}" # 确保这个目录存在
exec /usr/lib/rstudio-server/bin/rsession "${@}"
END

chmod +x "${workdir}/rsession.sh"

# 将临时的 rsession.sh 脚本 bind-mount 到容器内的 /etc/rstudio/rsession.sh
export SINGULARITY_BIND="${workdir}/rsession.sh:/etc/rstudio/rsession.sh"

# ====================================================================
# 4. 设置RStudio Server环境变量 (通过 Singularity 环境变量传递)
# ====================================================================
# 不挂起空闲会话 (RStudio Server Pro feature)
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

# 设置容器内 RStudio Server 登录凭据
export SINGULARITYENV_USER=$(id -un)            # 使用当前HPC用户名
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15) # 生成随机密码

# ====================================================================
# 5. 动态分配端口
# ====================================================================
# 获取一个未使用的本地端口
readonly PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

# 获取分配给任务的计算节点名称
HOSTNAME=$(hostname)

# ====================================================================
# 6. 打印连接信息和凭据到标准输出
# ====================================================================
cat 1>&2 <<END

===============================================================
RStudio Server is starting on node: ${HOSTNAME}
===============================================================

To connect to RStudio Server:

1. On your local machine, open a new terminal and create an SSH tunnel:

   ssh -N -L 8787:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@hpc_login_node_ip

   (Replace 'hpc_login_node_ip' with your cluster's login node address)

2. Then, open your web browser and go to: http://localhost:8787

3. Log in to RStudio Server using these credentials:

   User:     ${SINGULARITYENV_USER}
   Password: ${SINGULARITYENV_PASSWORD}

When you are done with RStudio Server:

1. In the RStudio window, click the "power" button (top right corner) to exit the RStudio Session.
2. On the HPC login node, terminate this Slurm job:

   scancel -f ${SLURM_JOB_ID}

===============================================================
Script will now wait for RStudio Server to terminate...
===============================================================

END

# ====================================================================
# 7. 启动 Singularity 容器中的 RStudio Server
# ====================================================================
singularity exec --cleanenv \
                 --scratch /run,/tmp,/var/lib/rstudio-server \
                 --workdir "${workdir}" \
                 --bind "$HOST_RSTUDIO_DIR":"$CONTAINER_MOUNT_POINT" \
                 --bind "$SINGULARITY_BIND" \
                 "$RSERVER_SIF" \
                 rserver --www-port "${PORT}" \
                         --auth-none=0 \
                         --auth-pam-helper-path=pam-helper \
                         --auth-stay-signed-in-days=30 \
                         --auth-timeout-minutes=0 \
                         --server-user="$(id -un)" \
                         --rsession-path=/etc/rstudio/rsession.sh

# ====================================================================
# 8. 清理临时目录
# ====================================================================
echo "RStudio Server process has terminated. Cleaning up temporary directory: $workdir" 1>&2
rm -rf "$workdir"

echo "Slurm job ending." 1>&2
