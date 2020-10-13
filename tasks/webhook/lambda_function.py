"""Route webhook messages to an amqp queue (AWS Lambda version)."""
# import os

import base64

# do we need cloudwatch logs? hmm
# import sentry_sdk
# from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration

# probably not correct, figure out later
import github_handler

# if misc.is_production():
#     sentry_sdk.init(
#         ca_certs=os.getenv('REQUESTS_CA_BUNDLE'),
#         integrations=[AwsLambdaIntegration()]
#     )

def lambda_handler(event, _):
    body = event.get('body')
    if body:
        # re-encode the body so the same code path can be shared by the
        # standalone server
        body = body.encode('utf-8')

    print('BODY', body)
    handler = github_handler.GithubHandler(event['headers'], body)
    status_code, message = handler.handle()

    # TODO format?
    return {'statusCode': status_code, 'body': message}


# hmmm do we need sentry/cloudwatch?
# def sentry_lambda(event, _):
#     """Process a webhook."""
#     return _lambda_handler(receiver.sentry_handler, event)
