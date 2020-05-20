import sys
import logging
import boto3
from botocore.exceptions import ClientError


def upload_file(endpoint, file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then same as file_name
    :return: True if file was uploaded, else False
    """
    access_key = 'user1'
    secret_key = 'user1'

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = file_name

    # Upload the file
    s3_client = boto3.client('s3',aws_access_key_id = access_key, aws_secret_access_key = secret_key, endpoint_url = endpoint)
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        logging.error(e)
        return False
    return True


def main():

    # Set these values before running the program
    # ex: python backup_to_umstor.py bucket1 
    bucket_name = sys.argv[1]
    file_name = sys.argv[2]
    object_name = sys.argv[3]

    endpoint = "http://192.168.180.138:8000"      

    # Set up logging
    logging.basicConfig(level=logging.DEBUG,
                        format='%(levelname)s: %(asctime)s: %(message)s')

    # Upload a file
    response = upload_file(endpoint, file_name, bucket_name, object_name)
    if response:
        logging.info('File was uploaded')


if __name__ == '__main__':
    main()