FROM mcr.microsoft.com/java/maven:8u192-zulu-debian9 AS maven

ADD dependencies /dep

RUN mvn -f /dep dependency:copy-dependencies

FROM mcr.microsoft.com/java/jre:8u192-zulu-alpine AS build

# Install Python
RUN apk add --no-cache python3-dev

RUN python3 -m venv /venv

# install requirements separately to prevent pip from downloading and
# installing pypi dependencies every time a file in your project changes
ADD ./requirements.txt /project/
RUN /venv/bin/pip install -r /project/requirements.txt

# install the project, basically copying its code, into the virtualenv.
# this assumes the project has a functional setup.py
ADD . /project
RUN /venv/bin/pip install /project

# this won't have any effect on our production image, is only meant for
# if we want to run commands like pytest in the build image
WORKDIR /project

# the second, production stage can be much more lightweight:
FROM mcr.microsoft.com/java/jre:8u192-zulu-alpine AS production

# Install Python
RUN apk add --no-cache python3 bash

COPY --from=build /venv /venv

COPY --from=maven /dep/target/dependency /venv/lib/python3.6/site-packages/pyspark/jars

ENV PYSPARK_PYTHON /venv/bin/python3

# remember to run python from the virtualenv
CMD ["/venv/bin/python3", "-m", "generator"]
