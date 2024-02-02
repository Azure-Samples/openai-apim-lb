## :page_with_curl: Working with the Policy

This guide provides insights into customizing API Management policies to enable smart load balancing for Azure OpenAI endpoints. While Azure API Management does not natively support this scenario, custom policies offer a flexible solution. Below, we explore the key components of these policies, their configuration, and their role in efficient load management.

### Understanding `listBackends` Variable Configuration

The `listBackends` variable is crucial as it defines the backends and their priorities. This example demonstrates setting up various endpoints with priorities and throttling status. 

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
        { "url", "https://openai1-eastus.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false }, 
        { "retryAfter", DateTime.MinValue } 
    });

    backends.Add(new JObject()
    {
        { "url", "https://openai2-eastus2.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    backends.Add(new JObject()
    {
        { "url", "https://openai3-canadaeast.openai.azure.com/" },
        { "priority", 2},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    backends.Add(new JObject()
    {
        { "url", "https://openai4-francecentral.openai.azure.com/" },
        { "priority", 3},
        { "isThrottling", false },
        { "retryAfter", DateTime.MinValue }
    });

    return backends;   
}" />
```

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
