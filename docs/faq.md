
## :question: FAQ

### I don't know anything about API Management. Where and how I add this code?
You just need to copy the contents of the [policy XML](apim-policy.xml), modify the backends list (from line 21 to 83) and paste into one of your APIs policies. There is an easy tutorial on how to do that [here](https://learn.microsoft.com/azure/api-management/set-edit-policies?tabs=form).

### What happens if all backends are throttling at the same time?
In that case, the policy will return the first backend in the list (line 158) and will forward the request to it. Since that endpoint is throttling, API Management will return the same 429 error as the OpenAI backend. That's why it is **still important for your client application/SDKs to have a logic to handle retries**, even though it should be much less frequent.

### I am updating the backend list in the policies but it seems to keep the old list.
That is because the policy is coded to only create the backend list after it expires in the internal cache, after 60 seconds. That means if your API Management instance is getting at least one request every 60 seconds, that cache will not expire to pick up your latest changes. You can either manually remove the cached "listBackends" key by using [cache-remove-key](https://learn.microsoft.com/azure/api-management/cache-remove-value-policy) policy or call its Powershell operation to [remove a cache](https://learn.microsoft.com/powershell/module/az.apimanagement/remove-azapimanagementcache?view=azps-10.4.1)

### Reading the policy logic is hard for me. Can you describe it in plain english?
Sure. This is how it works when API Management gets a new incoming request:

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
