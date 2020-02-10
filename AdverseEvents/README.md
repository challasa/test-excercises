This analysis was performed using AWS t2.2xlarge EC2 instance type.
RStudio Server Amazon Machine Image (AMI) from here  http://www.louisaslett.com/RStudio_AMI/ has been used to access RStudio Server

Created an EBS volume with 100GB memory and mounted that onto EC2 instance. Some of the commands in the reference below were used as part of initially exapnding the memory on the instance and later mounting the EBS volume as needed.
Ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/recognize-expanded-volume-linux.html
lsblk
sudo growpart /dev/xvda 1
sudo resize2fs /dev/xvda1
sudo mkdir /newvolume
sudo mount /dev/xvdf1 /newvolume

Other References:
https://open.fda.gov/apis/drug/event/
https://www.kaggle.com/msp48731/frequent-itemsets-and-association-rules
https://www.cs.upc.edu/~belanche/Docencia/mineria/Practiques/R/arules.pdf
https://www.datacamp.com/community/tutorials/market-basket-analysis-r
https://www.fda.gov/safety/reporting-serious-problems-fda/what-serious-adverse-event

