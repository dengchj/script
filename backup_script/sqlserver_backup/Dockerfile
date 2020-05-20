FROM 10749ad42dfb
MAINTAINER Chenjiong
COPY ./ulogs.ps1 /home/
RUN apt-get update \
  && apt-get install python \
  && python -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade pip \
  && pip install -i https://pypi.tuna.tsinghua.edu.cn/simple boto3
