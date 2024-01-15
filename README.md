![Smart APIM load balancing](./images/intro-loadbalance.png)

# :rocket: Smart load balancing for OpenAI endpoints and Azure API Management

Many service providers, including OpenAI usually set limits on the number of calls that can be made. In the case of Azure OpenAI, there are token limits (TPM or tokens per minute) and limits on the number of requests per minute (RPM). When a server starts running out of resources or the service limits are exhausted, the provider may issue a 429 or TooManyRequests HTTP Status code, and also a Retry-After response header indicating how much time you should wait until you try the next request.

The solution presented here is part of comprehensive one that takes into consideration things like a good UX/workflow design, adding application resiliency and fault-handling logic, considering service limits, choosing the right model for the job, the API policies, setting up logging and monitoring among other considerations. The solution shows how to create an Azure API Management Policy to seamlessly expose a single endpoint to your applications while keeping an efficient logic to consume two or more OpenAI or any API backends based on availability and priority.

## :sparkles: Why do you call this "smart" and different from round-robin load balancers?

One of the key components of handling OpenAI throttling is to be aware of the HTTP status code error 429 (Too Many Requests). There are [Tokens-Per-Minute and a Requests-Per-Minute](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/quota?tabs=rest#understanding-rate-limits) rate limiting in Azure OpenAI. Both situations will return the same error code 429.

Together with that HTTP status code 429, Azure OpenAI will also return a HTTP response header called "Retry-After", which is the number of seconds that instance will be unavailable before it starts accepting requests again.

These errors are normally handled in the client-side by SDKs. This works great if you have a single API endpoint. However, for multiple OpenAI endpoints (used for fallback) you would need to manage the list of URLs in the client-side too, which is not ideal.

What makes this API Management solution different than others is that it is aware of the "Retry-After" and 429 errors and intelligently sends traffic to other OpenAI backends that are not currently throttling. You can even have a priority order in your backends, so the highest priority are the ones being consumed first while they are not throttling. When throttling kicks in, API Management will fall back to lower priority backends while your highest ones are waiting to recover. 

Another important feature: there is no time interval between attempts to call different backends. Many of API Management sample policies out there configure a waiting internal (often exponential). While this is a good idea doing at the client side, making API Management to wait in the server-side of things is not a good practice because you hold your client and consume more API Management capacity during this waiting time. Retries on the server-side should be immediate and to a different endpoint.

Check this diagram for easier understanding:

![normal!](/images/apim-loadbalancing-active.png "Normal scenario")

![throttling!](/images/apim-loadbalancing-throttling.png "Throttling scenario")

## :1234: Priorities

One thing that stands out in the above images is the concept of "priority groups". Why do we have that? That's because you might want to consume all your available quota in specific instances before falling back to others. For example, in this scenario:
- You have a [PTU (Provisioned Throughput)](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/provisioned-throughput) deployment. You want to consume all its capacity first because you are paying for this either you use it or not. You can set this instance(s) as **Priority 1**
- Then you have extra deployments using the default S0 tier (token-based consumption model) spread in different Azure regions which you would like to fallback in case your PTU instance is fully occupied and returning errors 429. Here you don't have a fixed pricing model like in PTU but you will consume these endpoints only during the period that PTU is not available. You can set these as **Priority 2**

Another scenario:
- You don't have any PTU (provisioned) deployment but you would like to have many S0 (token-based consumption model) spread in different Azure regions in case you hit throttling. Let's assume your applications are mostly in USA.
- You then deploy one instance of OpenAI in each region of USA that has OpenAI capacity. You can set these instance(s) as **Priority 1**
- However, if all USA instances are getting throttled, you have another set of endpoints in Canada, which is closest region outside of USA. You can set these instance(s) as **Priority 2**
- Even if Canada also gets throttling at the same at as your USA instances, you can fallback to European regions now. You can set these instance(s) as **Priority 3**
- In the last case if all other previous endpoints are still throttling during the same time, you might even consider having OpenAI endpoints in Asia as "last resort". Latency will be little bit higher but still acceptable. You can set these instance(s) as **Priority 4**

And what happens if I have multiple backends with the same priority? Let's assume I have 3 OpenAI backends in USA with all Priority = 1 and all of them are not throttling? In this case, the algorithm will randomly pick among these 3 URLs.

## :gear: Setup instructions

1. Provision an [Azure API Management instance](https://learn.microsoft.com/en-us/azure/api-management/get-started-create-service-instance) and ensure that you enable `Managed Identity` during provisioning.
2. Provision your Azure OpenAI Service instances and deploy the same models and versions in each instance, while giving them the same name (e.g., name your deployment `gpt-35-turbo` or `gpt4-8k` in each instance and select the same version, e.g., `0613`)
3. For each Azure OpenAI Service instance, we need to add the Managed Identity of the API Management. For this, goto each Azure OpenAI instance in the Azure Portal, click `Access control (IAM)`, click `+ Add`, click `Add role assignment`, select the role `Cognitive Services OpenAI User`, click Next, select `Managed Identity` under `Assign access to`, then `+ Select Members`, and select the Managed Identity of your API Management instance. 
4. Download the desired API schema for Azure OpenAI Service, e.g., version [`2023-12-01-preview`](https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2023-12-01-preview/inference.json) or [any other version](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview)
5. Open `inference.json` in the editor of your choice and update the `servers` section ontop:
    ```
    "servers": [
        {
        "url": "https://microsoft.com/openai",
        "variables": {
            "endpoint": {
            "default": "itdoesntmatter.openai.azure.com"
            }
        }
        }
    ],
    ```
    We won't use this, but in order to import the file into API Management, we need to a correct URL there.
6. Goto your API Management instance in the Azure Portal, then select `API` on the left side, click `+ Add API` and select `OpenAI`
7. Load your `inference.json` and click `Create`.
> [!NOTE]   
> If you are using the Azure OpenAI SDK, make sure you set the API suffix to "something/**openai**". For example, "openai-load-balancing/**openai**". This is needed because the Azure OpenAI SDK automatically appends "/openai" in the requests and if that is missing in the API suffix, API Management will return 404 Not Found. Unless you want to use the API suffix solely as "openai", then there is no need to duplicate like "openai/openai".
8. Select the new API, goto `Settings`, goto `Subscription` and ensure `Subscription required` is checked and `Header name` is set to `api-key`. This is important to ensure compatibility with the OpenAI SDK.
9. Now edit `apim-policy.xml` from this repo and update the backend section as needed:
    ```
    backends.Add(new JObject()
    {
        { "url", "https://andre-openai-eastus.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false }, 
        { "retryAfter", DateTime.MinValue } 
    });
    ...
    ```
    Make sure you add all the Azure OpenAI instances you want to use and assign them the desired priority.
10. Goto back to API Management, select `Design`, select `All operations` and click the `</>` icon in inbound processing. Replace the code with the contents of your `apim-policy.xml`, then hit `Save`.
11. Lastly, goto `Subscriptions` (left menu) in API Management, select `+ Add Subscription`, give it a name and scope it `API` and select your `Azure OpenAI Service API`, click `Create`.
12. Then test if everything works by running some code of your choice, e.g., this code with OpenAI Python SDK:
    ```python
    from openai import AzureOpenAI

    client = AzureOpenAI(
        azure_endpoint="https://<your_APIM_endpoint>.azure-api.net/<your_api_suffix>", #do not add "/openai" at the end here because this will be automatically added by this SDK
        api_key="<your subscription key>",
        api_version="2023-12-01-preview"
    )

    response = client.chat.completions.create(
        model="<your_deployment_name>",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Does Azure OpenAI support customer managed keys?"}
        ]
    )
    print(response)
    ```

## :page_with_curl: Working with the policy

I'm using [API Management policies](https://learn.microsoft.com/azure/api-management/api-management-howto-policies) to define all this logic. API Management doesn't have built-in support for this scenario but by using custom policies we can achieve it. Let's take a look in the most important parts of the policy:

```xml
<set-variable name="listBackends" value="@{
    // -------------------------------------------------
    // ------- Explanation of backend properties -------
    // -------------------------------------------------
    // "url":          Your backend url
    // "priority":     Lower value means higher priority over other backends. 
    //                 If you have more one or more Priority 1 backends, they will always be used instead
    //                 of Priority 2 or higher. Higher values backends will only be used if your lower values (top priority) are all throttling.
    // "isThrottling": Indicates if this endpoint is returning 429 (Too many requests) currently
    // "retryAfter":   We use it to know when to mark this endpoint as healthy again after we received a 429 response

    JArray backends = new JArray();
    backends.Add(new JObject()
    {
        { "url", "https://andre-openai-eastus.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false }, 
        { "retryAfter", DateTime.MinValue } 
    });

    backends.Add(new JObject()
    {
        { "url", "https://andre-openai-eastus-2.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    backends.Add(new JObject()
    {
        { "url", "https://andre-openai-canadaeast.openai.azure.com/" },
        { "priority", 2},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    backends.Add(new JObject()
    {
        { "url", "https://andre-openai-francecentral.openai.azure.com/" },
        { "priority", 3},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    return backends;   
}" />
```

The variable `listBackends` at the beginning of the policy is the **only thing you need to change** to configure your backends and their priorities. In the above sample, we are telling API Management to consume US endpoints first (priority 1) and then falling back to Canada East (priority 2) and then France Central region (priority 3). We will use this array of JSON objects in API Management cache to share this property in the scope of all other incoming requests and not only in the scope of the current request. 

```xml
<authentication-managed-identity resource="https://cognitiveservices.azure.com" output-token-variable-name="msi-access-token" ignore-error="false" />
<set-header name="Authorization" exists-action="override">
    <value>@("Bearer " + (string)context.Variables["msi-access-token"])</value>
</set-header>
```

This part of the policy is injecting the Azure Managed Identity from your API Management instance as a HTTP header towards OpenAI. I highly recommend you do this because you don't need to keep track of different API-Keys for each backend. You just need to [turn on managed identity in API Management](https://learn.microsoft.com/azure/api-management/api-management-howto-use-managed-service-identity#create-a-system-assigned-managed-identity) and then [allow that identity in Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity)

Now let's explore and understand the other important pieces of this policy (nothing you need to change but good to be aware of):

```xml
<set-variable name="listBackends" value="@{
    JArray backends = (JArray)context.Variables["listBackends"];

    for (int i = 0; i < backends.Count; i++)
    {
        JObject backend = (JObject)backends[i];

        if (backend.Value<bool>("isThrottling") && DateTime.Now >= backend.Value<DateTime>("retryAfter"))
        {
            backend["isThrottling"] = false;
            backend["retryAfter"] = DateTime.MinValue;
        }
    }

    return backends; 
}" />
```

This piece of policy is called before every time we call OpenAI. It is just checking if any of the backends can be marked as healthy (not throttling) after we waited for the time specified in the "Retry-After" header.

```xml
<when condition="@(context.Response != null && (context.Response.StatusCode == 429 || context.Response.StatusCode.ToString().StartsWith("5")) )">
    <cache-lookup-value key="listBackends" variable-name="listBackends" />
    <set-variable name="listBackends" value="@{
        JArray backends = (JArray)context.Variables["listBackends"];
        int currentBackendIndex = context.Variables.GetValueOrDefault<int>("backendIndex");
        int retryAfter = Convert.ToInt32(context.Response.Headers.GetValueOrDefault("Retry-After", "10"));

        JObject backend = (JObject)backends[currentBackendIndex];
        backend["isThrottling"] = true;
        backend["retryAfter"] = DateTime.Now.AddSeconds(retryAfter);

        return backends;      
    }" />
```

This code is executed when there is a error 429 or 5xx coming from OpenAI. In case of errors 429, we will mark this backend as throttling and read the "Retry-After" header and add the number of seconds to wait before this is marked as not-throttling again. In case of unexpected 5xx errors, the waiting time will be 10 seconds.

There are other parts of the policy in the sources but these are the most relevant. The original [source XML](apim-policy.xml) you can find in this repo contains comments explaining what each section does.

### Scalability vs Reliability
This solution addresses both scalability and reliability concerns by allowing your total Azure OpenAI quotas to increase and providing server-side failovers transparently for your applications. However, if you are looking purely for a way to increase default quotas, I still would recommend that you follow the official guidance to [request a quota increase](https://learn.microsoft.com/azure/ai-services/openai/quotas-limits#how-to-request-increases-to-the-default-quotas-and-limits).

### Caching and multiple API Management instances
This policy is currently using API Management internal cache mode. That is a in-memory local cache. What if you have API Management running with multiple instances in one region or a multi-regional deployment? The side effect is that each instance will have its own list of backends. What might happen during runtime is this:
- API Management instance 1 receives a customer request and gets a 429 error from backend 1. It marks that backend as unavailable for X seconds and then reroute that customer request to next backend
- API Management instance 2 receives a customer request and sends that request again to backend 1 (since its local cached list of backends didn't have the information from API Management instance 1 when it marked as throttled). Backend 1 will respond with error 429 again and API Management instance 2 will also mark it as unavailable and reroutes the request to next backend

So, it might occur that internally, API Management instances will try route to throttled backends and will need to retry to another backend. Eventually, all instances will be in sync again at a small cost of unnecessary roundtrips to throttled endpoints.
I honestly think this is a very small price to pay, but if you want to solve that you can always change API Management [to use an external Redis cache](https://learn.microsoft.com/azure/api-management/api-management-howto-cache-external) so all instances will share the same cached object.

## :question: FAQ

### I don't know anything about API Management. Where and how I add this code?
You just need to copy the contents of the [policy XML](apim-policy.xml), modify the backends list (from line 21 to 83) and paste into one of your APIs policies. There is an easy tutorial on how to do that [here](https://learn.microsoft.com/azure/api-management/set-edit-policies?tabs=form).

### What happens if all backends are throttling at the same time?
In that case, the policy will return the first backend in the list (line 158) and will forward the request to it. Since that endpoint is throttling, API Management will return the same 429 error as the OpenAI backend. That's why it is **still important for your client application/SDKs to have a logic to handle retries**, even though it should be much less frequent.

### I am updating the backend list in the policies but it seems to keep the old list
That is because the policy is coded to only create the backend list after it expires in the internal cache, after 60 seconds. That means if your API Management instance is getting at least one request every 60 seconds, that cache will not expire to pick up your latest changes. You can either manually remove the cached "listBackends" key by using [cache-remove-key](https://learn.microsoft.com/azure/api-management/cache-remove-value-policy) policy or call its Powershell operation to [remove a cache](https://learn.microsoft.com/powershell/module/az.apimanagement/remove-azapimanagementcache?view=azps-10.4.1)

### Reading the policy logic is hard for me. Can you describe it in plain english?
Sure. That's how it works when API Management gets a new incoming request:

1. From the list of backends defined in the JSON array, it will pick one backend using this logic:
   1. Selects the highest priority (lower number) that is not currently throttling. If it finds more than one healthy backend with the same priority, it will randomly select one of them
2. Sends the request to the chosen backend URL
    1. If the backend responds with success (HTTP status code 200), the response is passed to the client and the flow ends here
    2. If the backend responds with error 429 or 5xx
        1. It will read the HTTP response header "Retry-After" to see when it will become available again
        2. Then, it marks that specific backend URL as throttling and also saves what time it will be healthy again
        3. If there are still other available backends in the pool, it runs again the logic to select another backend (go to the point 1. again and so on)
        4. If there are no backends available (all are throttling), it will send the customer request to the first backend defined in the list and return its response

### Are you sure that not having a waiting delay in API Management between the retries is the best way to do? I don't see a problem if client needs to wait more to have better chances to get a response.
Yes. Retries with exponential backoffs are a good fit for client applications and not servers/backends. Especially in this case, in which we need to buffer the HTTP body contents between the retries (```<forward-request buffer-request-body="true" />```), spending more time before sending the response has a heavy cost. To prove that point, I did an experiment: in a given API Management instance, I made a JMeter load testing script that will call it 4000 times per minute:
- One endpoint (called "No retry" in the image below) will just return HTTP status code 200 immediately
- The second endpoint (called "Retry in APIM" in the image below) will respond the same thing but it takes 30 seconds before doing so. In that mean time, the client keeps "waiting" and connection is kept open

Check the difference in the API Management capacity metric with the same number of  minute:

![apim-capacity!](/images/apim-retry.png)

The left part of the chart shows 20% average capacity for 4K RPM with API Management sends the response immediately. The right part of the chart shows 60% average capacity utilization with the same 4K RPM! Just because it holds the connection longer. That's 3 times more! The same behavior will happen if you configure API Management retries with waiting times: you will add extra pressure and it even might become a single point of failure in high traffic situations.

## :link: Related articles
- A more detailed and user-friendly step-by-step article by [csiebler](https://github.com/csiebler): [Smart Load-Balancing for Azure OpenAI with Azure API Management](https://clemenssiebler.com/posts/smart-loadbalancing-for-azure-openai-with-api-management/)
