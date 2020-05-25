#!/usr/bin/env zsh
# Pre-requisites:
#  - gdate
#  - netcat
#  - aws cli
#  - docker

region=us-west-2
logfile="agent.log"
current_time=$(gdate +%s%3N)
log_group_name="AgentBugRepro"
log_stream_name=$current_time

if [ ! -f "./credentials" ]; then
    echo 'Credentials file does not exist. Update and rename "credentials.sample" to "credentials"'
    echo 'This file is included in .gitignore'
    exit 1
fi

docker build -t agent:latest .
docker run -p 25888:25888/udp -p 25888:25888/tcp  \
    -e AWS_REGION=$region \
    --name cwagent \
    agent:latest &> $logfile &

echo "Waiting for agent to start."
tail -f $logfile | sed '/Loaded outputs: cloudwatchlogs/ q'
echo "Agent started."

current_time=$(date +%s%3N)
sed -e s/\${timestamp}/$current_time/ \
    -e s/\${lg}/$log_group_name/ \
    -e s/\${ls}/$log_stream_name/ emf.json \
    | netcat 127.0.0.1 25888 &

# wait until the agent writes the metrics to the output
tail -f $logfile | sed '/logpusher: publish/ q'

# get events from
echo "Sleeping to allow logs to become available."
sleep 2
aws logs get-log-events --log-group-name $log_group_name --log-stream-name $log_stream_name

# cleanup
docker stop $(docker ps -aq --filter="name=cwagent")
docker rm $(docker ps -aq --filter="name=cwagent")