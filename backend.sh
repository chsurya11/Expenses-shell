#!bin/bash

USERID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOG_FOLDER="/var/log/expense-logs"
LOG_FILE=$(echo $0 | cut -d "." -f1)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE_NAME="$LOG_FOLDER/$LOG_FILE-$TIMESTAMP.log"

VALIDATE(){
    if [ $1 -ne 0 ]
    then
        echo -e "$2 ... $R FAILURE $N"
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N"
    fi
}

CHECK_ROOT(){
    if [ $USERID -ne 0 ]
    then
        echo "ERROR: you must have a sudo access to execute this script"
    exit 1
    fi
}

echo "Script started executing at: $TIMESTAMP" &>>$LOG_FILE_NAME

CHECK_ROOT

dnf module disable nodejs -y &>>$LOG_FILE_NAME
VALIDATE $? "Disabling existing default Nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE_NAME
VALIDATE $? "Enabling NodeJS 20"

dnf install nodejs -y &>>$LOG_FILE_NAME
VALIDATE $? "Installing Node JS"

id expense &>>$LOG_FILE_NAME
if [ $? -ne 0 ]
then
    useradd expense &>>$LOG_FILE_NAME
    VALIDATE $? "Adding Expense user"
else
    echo -e "expense user already exits... $Y SKIPPING $N"
fi

mkdir -p /app &>>$LOG_FILE_NAME
VALIDATE $? "Creating app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE_NAME
VALIDATE $? "Downloading backend"

cd /app
rm -rf /app/*

unzip /tmp/backend.zip &>>$LOG_FILE_NAME
VALIDATE $? "Unzip backend"

npm install &>>$LOG_FILE_NAME
VALIDATE $? "Installing backend"

cp /home/ec2-user/Expenses-shell/backend.service /etc/systemd/system/backend.service &>>$LOG_FILE_NAME

dnf install mysql -y &>>$LOG_FILE_NAME
VALIDATE $? "Installing MYSQL Client"

mysql -h mysql.jiocoinmarket.online -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$LOG_FILE_NAME
VALIDATE $? "Setting up the transaction schema and tables"

systemctl daemon-reload &>>$LOG_FILE_NAME
VALIDATE $? "Daemon-reload"

systemctl start backend &>>$LOG_FILE_NAME
VALIDATE $? "Starting backend"

systemctl enable backend &>>$LOG_FILE_NAME
VALIDATE $? "Enabling backend"

systemctl restart backend &>>$LOG_FILE_NAME
VALIDATE $? "Restart backend"