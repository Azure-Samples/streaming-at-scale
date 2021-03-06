// <auto-generated>
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for
// license information.
//
// Code generated by Microsoft (R) AutoRest Code Generator.
// Changes may cause incorrect behavior and will be lost if the code is
// regenerated.
// </auto-generated>

namespace Microsoft.Azure.TimeSeriesInsights
{
    using Microsoft.Rest;
    using Models;
    using System.Collections;
    using System.Collections.Generic;
    using System.Threading;
    using System.Threading.Tasks;

    /// <summary>
    /// TimeSeriesInstances operations.
    /// </summary>
    public partial interface ITimeSeriesInstances
    {
        /// <summary>
        /// Gets time series instances in pages.
        /// </summary>
        /// <param name='continuationToken'>
        /// Continuation token from previous page of results to retrieve the
        /// next page of the results in calls that support pagination. To get
        /// the first page results, specify null continuation token as
        /// parameter value. Returned continuation token is null if all results
        /// have been returned, and there is no next page of results.
        /// </param>
        /// <param name='clientRequestId'>
        /// Optional client request ID. Service records this value. Allows the
        /// service to trace operation across services, and allows the customer
        /// to contact support regarding a particular request.
        /// </param>
        /// <param name='clientSessionId'>
        /// Optional client session ID. Service records this value. Allows the
        /// service to trace a group of related operations across services, and
        /// allows the customer to contact support regarding a particular group
        /// of requests.
        /// </param>
        /// <param name='customHeaders'>
        /// The headers that will be added to request.
        /// </param>
        /// <param name='cancellationToken'>
        /// The cancellation token.
        /// </param>
        /// <exception cref="TsiErrorException">
        /// Thrown when the operation returned an invalid status code
        /// </exception>
        /// <exception cref="Microsoft.Rest.SerializationException">
        /// Thrown when unable to deserialize the response
        /// </exception>
        /// <exception cref="Microsoft.Rest.ValidationException">
        /// Thrown when a required parameter is null
        /// </exception>
        Task<HttpOperationResponse<GetInstancesPage,TimeSeriesInstancesListHeaders>> ListWithHttpMessagesAsync(string continuationToken = default(string), string clientRequestId = default(string), string clientSessionId = default(string), Dictionary<string, List<string>> customHeaders = null, CancellationToken cancellationToken = default(CancellationToken));
        /// <summary>
        /// Executes a batch get, create, update, delete operation on multiple
        /// time series instances.
        /// </summary>
        /// <param name='parameters'>
        /// Time series instances suggest request body.
        /// </param>
        /// <param name='clientRequestId'>
        /// Optional client request ID. Service records this value. Allows the
        /// service to trace operation across services, and allows the customer
        /// to contact support regarding a particular request.
        /// </param>
        /// <param name='clientSessionId'>
        /// Optional client session ID. Service records this value. Allows the
        /// service to trace a group of related operations across services, and
        /// allows the customer to contact support regarding a particular group
        /// of requests.
        /// </param>
        /// <param name='customHeaders'>
        /// The headers that will be added to request.
        /// </param>
        /// <param name='cancellationToken'>
        /// The cancellation token.
        /// </param>
        /// <exception cref="TsiErrorException">
        /// Thrown when the operation returned an invalid status code
        /// </exception>
        /// <exception cref="Microsoft.Rest.SerializationException">
        /// Thrown when unable to deserialize the response
        /// </exception>
        /// <exception cref="Microsoft.Rest.ValidationException">
        /// Thrown when a required parameter is null
        /// </exception>
        Task<HttpOperationResponse<InstancesBatchResponse,TimeSeriesInstancesExecuteBatchHeaders>> ExecuteBatchWithHttpMessagesAsync(InstancesBatchRequest parameters, string clientRequestId = default(string), string clientSessionId = default(string), Dictionary<string, List<string>> customHeaders = null, CancellationToken cancellationToken = default(CancellationToken));
        /// <summary>
        /// Suggests keywords based on time series instance attributes to be
        /// later used in Search Instances.
        /// </summary>
        /// <param name='parameters'>
        /// Time series instances suggest request body.
        /// </param>
        /// <param name='clientRequestId'>
        /// Optional client request ID. Service records this value. Allows the
        /// service to trace operation across services, and allows the customer
        /// to contact support regarding a particular request.
        /// </param>
        /// <param name='clientSessionId'>
        /// Optional client session ID. Service records this value. Allows the
        /// service to trace a group of related operations across services, and
        /// allows the customer to contact support regarding a particular group
        /// of requests.
        /// </param>
        /// <param name='customHeaders'>
        /// The headers that will be added to request.
        /// </param>
        /// <param name='cancellationToken'>
        /// The cancellation token.
        /// </param>
        /// <exception cref="TsiErrorException">
        /// Thrown when the operation returned an invalid status code
        /// </exception>
        /// <exception cref="Microsoft.Rest.SerializationException">
        /// Thrown when unable to deserialize the response
        /// </exception>
        /// <exception cref="Microsoft.Rest.ValidationException">
        /// Thrown when a required parameter is null
        /// </exception>
        Task<HttpOperationResponse<InstancesSuggestResponse,TimeSeriesInstancesSuggestHeaders>> SuggestWithHttpMessagesAsync(InstancesSuggestRequest parameters, string clientRequestId = default(string), string clientSessionId = default(string), Dictionary<string, List<string>> customHeaders = null, CancellationToken cancellationToken = default(CancellationToken));
        /// <summary>
        /// Partial list of hits on search for time series instances based on
        /// instance attributes.
        /// </summary>
        /// <param name='parameters'>
        /// Time series instances search request body.
        /// </param>
        /// <param name='continuationToken'>
        /// Continuation token from previous page of results to retrieve the
        /// next page of the results in calls that support pagination. To get
        /// the first page results, specify null continuation token as
        /// parameter value. Returned continuation token is null if all results
        /// have been returned, and there is no next page of results.
        /// </param>
        /// <param name='clientRequestId'>
        /// Optional client request ID. Service records this value. Allows the
        /// service to trace operation across services, and allows the customer
        /// to contact support regarding a particular request.
        /// </param>
        /// <param name='clientSessionId'>
        /// Optional client session ID. Service records this value. Allows the
        /// service to trace a group of related operations across services, and
        /// allows the customer to contact support regarding a particular group
        /// of requests.
        /// </param>
        /// <param name='customHeaders'>
        /// The headers that will be added to request.
        /// </param>
        /// <param name='cancellationToken'>
        /// The cancellation token.
        /// </param>
        /// <exception cref="TsiErrorException">
        /// Thrown when the operation returned an invalid status code
        /// </exception>
        /// <exception cref="Microsoft.Rest.SerializationException">
        /// Thrown when unable to deserialize the response
        /// </exception>
        /// <exception cref="Microsoft.Rest.ValidationException">
        /// Thrown when a required parameter is null
        /// </exception>
        Task<HttpOperationResponse<SearchInstancesResponsePage,TimeSeriesInstancesSearchHeaders>> SearchWithHttpMessagesAsync(SearchInstancesRequest parameters, string continuationToken = default(string), string clientRequestId = default(string), string clientSessionId = default(string), Dictionary<string, List<string>> customHeaders = null, CancellationToken cancellationToken = default(CancellationToken));
    }
}
