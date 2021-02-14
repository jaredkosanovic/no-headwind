# No Headwind

https://noheadwind.com

My personal blog made with the help of Hugo and AWS.

Big thanks to the [Hugo Clarity theme](https://themes.gohugo.io/hugo-clarity/).

## Run Locally

1. [Install Hugo](https://gohugo.io/overview/installing/)
2. Clone this repository and run locally.
    ```bash
    git clone git@github.com:jaredkosanovic/no-headwind.git
    cd no-headwind
    hugo server -D
    ```
3. Open http://localhost:1313/ in a browser.

## Deploy

1. Provision AWS infrastructure.
    ```bash
    cd terraform
    terraform init -backend-config="<s3-bucket-for-tfstate>"
    terraform apply
    cd ..
    ```
2. Copy static resources to S3.
    ```bash
    hugo -b https://noheadwind.com/ -d public
    aws s3 sync --delete public s3://noheadwind.com    
    ```
3. Open https://noheadwind.com in a browser.
