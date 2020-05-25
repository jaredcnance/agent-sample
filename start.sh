logfile="agent.log"

echo $AWS_REGION

docker build -t agent:latest .
docker run  -p 25888:25888/udp -p 25888:25888/tcp  \
    -e AWS_REGION=$AWS_REGION \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    agent:latest &> $logfile &

echo "Waiting for agent to start."
tail -f $logfile | sed '/Loaded outputs: cloudwatchlogs/ q'
echo "Agent started."

current_time=$(date +%s%3N)
sed -e s/\${timestamp}/$current_time/ emf.json > /dev/tcp/127.0.0.1/25888