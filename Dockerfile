FROM 18fgsa/docker-ruby-ubuntu
RUN apt-get update

# Defaults for ENV vairables
ENV AWS_DEFAULT_REGION "us-east-1"

# skip installing gem documentation
RUN echo 'install: --no-document\nupdate: --no-document' >> "/etc/.gemrc"

# Install the AWS SDK and MIME for publishing
RUN bin/bash -l -c "gem install aws-sdk mime-types"

# node-gyp needs Python 2.7
RUN apt-get install -y python2.7
ENV PYTHON /usr/bin/python2.7

# Copy the script files
COPY *.sh /app/
COPY *.rb /app/

# Add the working directory
WORKDIR /src

# Run the build script when container starts
CMD ["bash", "/app/run.sh"]
