"""Route webhook messages to an amqp queue (AWS Lambda version)."""
# import os

# do we need cloudwatch logs? hmm
# import sentry_sdk
# from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration

# probably not correct, figure out later
import cockpituous.tasks.github_handler

# if misc.is_production():
#     sentry_sdk.init(
#         ca_certs=os.getenv('REQUESTS_CA_BUNDLE'),
#         integrations=[AwsLambdaIntegration()]
#     )

def github_lambda(event, _):
    headers = event['headers']
    body = event['body'].encode('utf8')

    handler = github_handler.GithubHandler(headers, body)
    status_code, message = handler.handle()

    # TODO format?
    return {'statusCode': status_code, 'body': message}


# hmmm do we need sentry/cloudwatch?
# def sentry_lambda(event, _):
#     """Process a webhook."""
#     return _lambda_handler(receiver.sentry_handler, event)

