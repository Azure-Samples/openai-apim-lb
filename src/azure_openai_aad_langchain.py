import os
from azure.identity import DefaultAzureCredential
from langchain_openai import AzureChatOpenAI
from dotenv import load_dotenv


load_dotenv()

apim_endpoint = os.getenv("APIM_ENDPOINT")
audience = os.getenv("AZURE_AUDIENCE")+ "/.default"

# Get the Azure Credential
credential = DefaultAzureCredential()

# Set the API type to `azure_ad`
os.environ["OPENAI_API_TYPE"] = "azure_ad"
os.environ["OPENAI_API_VERSION"] = "2023-12-01-preview"
# Set the API_KEY to the token from the Azure credential
os.environ["OPENAI_API_KEY"] = credential.get_token(audience).token

llm = AzureChatOpenAI(
    deployment_name="chat",
    model_name="gpt-35-turbo",
    azure_endpoint=apim_endpoint,
)


messages = [
   {"role": "system", "content": "You are a helpful assistant."},
   {"role": "user", "content": "Does Azure OpenAI support customer managed keys?"}
]

print( llm.invoke(messages) )
