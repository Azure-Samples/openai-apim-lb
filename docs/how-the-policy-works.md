## :page_with_curl: Gateway routing strategies (APIM)

When it comes to GenAI APIs, the need for advanced routing strategies arises to manage the capacity and resiliency for smooth AI-infused experiences across multiple clients.

Setting these policies in APIM will allow for advanced routing based on the region and model in addition to the priority and throttling fallback.

Dimensions of the routing strategies using APIM include:
- **Global vs. regional**: Ability to route to traffic to different regional gateway might be a requirement to ensure low latency, high availability and data residency.
    - For example, if you have a global deployment of AI Hub Gateway, you might want to route traffic to the nearest gateway to the client, or route that traffic to a specific gateway based on regulatory requirements.
- **Model-based routing**: Ability to route to traffic based on requested model is critical as not all OpenAI regional deployments support all capabilities and versions.
    - For example, if you can have gpt-4-vision model that is only available in 2 regions, you might want to load balance traffic to these 2 regions only.
- **Priority based routing**: Ability to route traffic based on priority is critical to ensure that the traffic is routed to preferred region first and fall back to other deployments when primary deployment is not available.
    - For example, if you have a Provisioned Throughput Unit (PTU) deployment in certain region, you might want to route all traffic to that deployment to maximize its utilization and only fall back to a secondary deployment in another region when the PTU is throttling (this also should revert back to primary when it is available again).
- **Throttling fallback support**: Ability to take a specific route out of the routing pool if it is throttling and fall back to the next available route.
    - For example, if you have a OpenAI deployment that is throttling, AI Hub Gateway should be able to take it out of the routing pool and fall back to the next available deployment and register the time needed before it is available again you might want so it can be brought back into the pool.
- **Configuration update**: Ability to update the routing configuration without affecting the existing traffic is critical to allow for rolling updates of the routing configuration.
    - For example, if you have a new OpenAI deployment that is available, you might want to update the routing configuration to include it and allow for new traffic to be routed to it without affecting the existing traffic (and in also support rolling back certain update when needed).

## Working with the Policy

This guide provides insights into customizing API Management policies to enable smart load balancing for Azure OpenAI endpoints. While Azure API Management does not natively support this scenario, custom policies offer a flexible solution. Below, we explore the key components of these policies, their configuration, and their role in efficient load management.

### Understanding `oaClusters`

**Clusters (model based routing)**: it is a simple concept to group multiple OpenAI endpoints that support specific OpenAI deployment name (specific model and version). 
    - For example, if the model is gpt-4 and it exists only in 2 OpenAI instances, I will create a cluster with these 2 endpoints only. On the other hand, gpt-35-turbo exists in 5 OpenAI instances, I will create a cluster with these 5 endpoints.
    - In order for this routing to work, OpenAI deployment names across regions must use the same name as I rely on the URL path to extract the direct deployment name which then results in specific routes to be used.

### Understanding `routes` Variable Configuration

The `routes` variable is crucial as it defines the OpenAI endpoints and their priorities. This example demonstrates setting up various endpoints with priorities and throttling status. 

   - Each cluster will reference supported route from this json array
    - Each route will have a friendly name, location, priority, and throttling status.

This sample deployment, creates 3 OpenAI instances in 3 different regions (EastUS, NorthCentralUS, EastUS2) and assigns them to the same priority level (which mean they will all be available for routing).

You can also see that this sample configuration is using a single region deployment of APIM gateway indicated by the always true condition `if(context.Deployment.Region == "West Europe" || true)`. 

This is to show how you can configure different routing configuration based on the region of the APIM gateway.

```xml
<set-variable name="oaClusters" value="@{
    // route is an Azure OpenAI API endpoints
    JArray routes = new JArray();
    // cluster is a group of routes that are capable of serving a specific deployment name (model and version)
    JArray clusters = new JArray();
    // Update the below if condition when using multiple APIM gateway regions/SHGW to get different configuartions for each region
    if(context.Deployment.Region == "West Europe" || true)
    {
        // Adding all Azure OpenAI endpoints routes (which are set as APIM Backend)
        routes.Add(new JObject()
        {
            { "name", "EastUS" },
            { "location", "eastus" },
            { "backend-id", "openai-backend-0" },
            { "priority", 1},
            { "isThrottling", false }, 
            { "retryAfter", DateTime.MinValue } 
        });

        routes.Add(new JObject()
        {
            { "name", "NorthCentralUS" },
            { "location", "northcentralus" },
            { "backend-id", "openai-backend-1" },
            { "priority", 1},
            { "isThrottling", false },
            { "retryAfter", DateTime.MinValue }
        });

        routes.Add(new JObject()
        {
            { "name", "EastUS2" },
            { "location", "eastus2" },
            { "backend-id", "openai-backend-2" },
            { "priority", 1},
            { "isThrottling", false },
            { "retryAfter", DateTime.MinValue }
        });

        // For each deployment name, create a cluster with the routes that can serve it
        // It is important in you OpenAI deployments to use the same name across instances
        clusters.Add(new JObject()
        {
            { "deploymentName", "chat" },
            { "routes", new JArray(routes[0], routes[1], routes[2]) }
        });

        clusters.Add(new JObject()
        {
            { "deploymentName", "embedding" },
            { "routes", new JArray(routes[0], routes[1], routes[2]) }
        });

        //If you want to add additional speical models like DALL-E or GPT-4, you can add them here
        //In this cluster, DALL-E is served by one OpenAI endpoint route and GPT-4 is served by two OpenAI endpoint routes
        //clusters.Add(new JObject()
        //{
        //    { "deploymentName", "dall-e-3" },
        //    { "routes", new JArray(routes[0]) }
        //});

        //clusters.Add(new JObject()
        //{
        //    { "deploymentName", "gpt-4" },
        //    { "routes", new JArray(routes[0], routes[1]) }
        //});
        
    }
    else
    {
        //No clusters found for selected region, either return error (defult behavior) or set default cluster in the else section
    }
    
    return clusters;   
}" />
```
### Safe configuration changes

**Caching**: caching the clusters and routes allow it to be shared across multiple API calls.

```xml
<cache-store-value key="@("oaClusters" + context.Deployment.Region + context.Api.Revision)" value="@((JArray)context.Variables["oaClusters"])" duration="60" />
...
<cache-store-value key="@(context.Request.MatchedParameters["deployment-id"] + "Routes" + context.Deployment.Region + context.Api.Revision)" value="@((JArray)context.Variables["routes"])" duration="60" />
```

You can see that cache key is taking into consideration region, model deployment name and API revision to ensure that the cache is unique for each configuration.

If you need to update the configuration, I would recommend creating first a new API revision, update the configuration and test it. 

Once you are happy with the new configuration, you can update the API to use the new revision as the current revision.

If something went wrong, you can always rollback to the previous revision.

### Authentication Managed Identity

This section of the policy injects the Azure Managed Identity from your API Management instance as an HTTP header for OpenAI. This method is recommended for ease of API key management across different backends. 
```xml
<authentication-managed-identity resource="https://cognitiveservices.azure.com" output-token-variable-name="msi-access-token" ignore-error="false" />
<set-header name="Authorization" exists-action="override">
    <value>@("Bearer " + (string)context.Variables["msi-access-token"])</value>
</set-header>
```

### Backend Health Check

Before every call to OpenAI, the policy checks if any backends can be marked as healthy after the specified "Retry-After" period.
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

### Handling 429 and 5xx Errors

This code segment is triggered when a 429 or 5xx error occurs, updating the backend status accordingly based on the "Retry-After" header. 
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

There are other parts of the policy in the sources but these are the most relevant. The original [source XML](apim-policy.xml) you can find in this repo contains comments explaining what each section does.

### Scalability and Reliability in Load Balancing

This solution adeptly addresses both scalability and reliability in managing Azure OpenAI quotas. By enhancing the total quota capacity and implementing server-side failovers, it ensures robust application performance. However, for scenarios focused exclusively on increasing default quotas, it is recommended to follow the [official guidelines for requesting a quota increase](https://learn.microsoft.com/azure/ai-services/openai/quotas-limits#how-to-request-increases-to-the-default-quotas-and-limits).

### Caching in Multi-Instance API Management Deployments

The policy employs API Management's internal cache mode, utilizing in-memory local caching. In environments with multiple API Management instances, either in a single region or spread across multiple regions, each instance maintains its own backend list. This setup could lead to scenarios where:

- An instance receives a request and encounters a 429 error from a backend, marking it as unavailable and rerouting to the next available backend.
- Another instance, unaware of the first instance's encounter with a 429 error, attempts to route a request to the same backend, only to encounter the same error and mark it as unavailable before rerouting.

While this could result in some unnecessary request roundtrips to throttled endpoints, it's generally a minor trade-off for maintaining local cache simplicity. However, for synchronized caching across all instances, implementing an [external Redis cache](https://learn.microsoft.com/azure/api-management/api-management-howto-cache-external) is recommended. This approach ensures all instances share the same backend status information, enhancing efficiency in load balancing.
