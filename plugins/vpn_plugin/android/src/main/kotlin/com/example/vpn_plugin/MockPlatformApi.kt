package com.example.vpn_plugin

import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.Closeable

class MockPlatformApi: PlatformApi, EventChannel.StreamHandler, Closeable {
    private val scope = CoroutineScope(Dispatchers.Main)
    private var job: Job? = null
    private var eventSink: EventChannel.EventSink? = null
    private var servers: MutableList<Server> = mutableListOf()
    private var requests = mutableListOf<VpnRequest>()
    private var selectedServerId: Long? = null
    private var state: VpnManagerState = VpnManagerState.DISCONNECTED
    private var excludedRoutes = ""


    init {
        for (i in 1..3) {
            servers.add(Server(
                id = i.toLong(),
                name = "Server $i",
                ipAddress = "192.168.1.$i",
                domain = "server$i.com",
                login = "login$i",
                password = "password$i",
                protocol = VpnProtocol.HTTP2,
                routingProfileId = 0,
                dnsServers = listOf(),
            ))
        }
        for (i in 1..20) {
            requests.add(VpnRequest(
                time = "01.07.2024 18.48.11",
                protocol = VpnProtocol.HTTP2,
                decision = RoutingMode.BYPASS,
                sourceIpAddress = "192.168.1.$i",
                destinationIpAddress = "192.168.1.$i",
                sourcePort = "80",
                destinationPort = "80",
                domain = "server$i.com",
            ))
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events!!
        onStateChanged()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun getAllServers(): List<Server> {
        return servers
    }

    override fun getServerById(id: Long): Server {
        return servers.find { it.id == id }!!
    }

    override fun addServer(request: AddServerRequest): Server {
        val errors = mutableListOf<PlatformFieldError>()
        if (request.name.length == 1) {
            errors.add(PlatformFieldError(
                code = PlatformFieldErrorCode.ALREADY_EXISTS,
                fieldName = PlatformFieldName.SERVER_NAME,))
        }
        if (request.ipAddress.length == 1) {
            errors.add(PlatformFieldError(
                code = PlatformFieldErrorCode.FIELD_WRONG_VALUE,
                fieldName = PlatformFieldName.IP_ADDRESS,))
        }
        if (request.domain.length == 1) {
            errors.add(PlatformFieldError(
                code = PlatformFieldErrorCode.FIELD_WRONG_VALUE,
                fieldName = PlatformFieldName.DOMAIN,))
        }
        if (request.dnsServers.size == 2) {
            errors.add(PlatformFieldError(
                code = PlatformFieldErrorCode.FIELD_WRONG_VALUE,
                fieldName = PlatformFieldName.DNS_SERVERS,))
        }

        if (errors.isNotEmpty()) {
            throw FlutterError(
                code = "",
                message = null,
                details = PlatformErrorResponse(
                    fieldErrors = errors,
                )
            )
        }

        val server = Server(
            id = servers.size.toLong() + 1,
            name = request.name,
            ipAddress = request.ipAddress,
            domain = request.domain,
            login = request.login,
            password = request.password,
            protocol = request.protocol,
            routingProfileId = request.routingProfileId,
            dnsServers = request.dnsServers,
        )
        servers.add(server)

        return server
    }

    override fun updateServer(request: UpdateServerRequest): Server {
        val server = Server(
            id = request.id,
            name = request.name,
            ipAddress = request.ipAddress,
            domain = request.domain,
            login = request.login,
            password = request.password,
            protocol = request.protocol,
            routingProfileId = request.routingProfileId,
            dnsServers = request.dnsServers,
        )
        val index = servers.indexOfFirst { it.id == request.id }
        if (index != -1) {
            servers[index] = server
        }


        return server
    }

    override fun removeServer(id: Long) {
        servers = servers.filter { it.id != id }.toMutableList()
    }

    override fun getSelectedServerId(): Long? {
        return selectedServerId
    }

    override fun setSelectedServerId(id: Long) {
        selectedServerId = id
    }

    override fun getAllRoutingProfiles(): List<RoutingProfile> {
        TODO("Not yet implemented")
    }

    override fun getRoutingProfileById(id: Long): RoutingProfile {
        TODO("Not yet implemented")
    }

    override fun addRoutingProfile(request: AddRoutingProfileRequest): RoutingProfile {
        TODO("Not yet implemented")
    }

    override fun updateRoutingProfile(request: UpdateRoutingProfileRequest): RoutingProfile {
        TODO("Not yet implemented")
    }

    override fun setRoutingProfileName(name: String) {
        TODO("Not yet implemented")
    }

    override fun removeRoutingProfile(id: Long) {
        TODO("Not yet implemented")
    }

    override fun getAllRequests(): List<VpnRequest> {
        return requests
    }

    override fun setExcludedRoutes(routes: String) {
        excludedRoutes = routes
    }

    override fun getExcludedRoutes(): String {
        return excludedRoutes
    }

    override fun start() {
        job?.cancel()
        state = VpnManagerState.CONNECTING
        onStateChanged()
        job = scope.launch {
            delay(3000)
            state = VpnManagerState.CONNECTED
            onStateChanged()
        }
    }

    override fun stop() {
        job?.cancel()
        state = VpnManagerState.DISCONNECTED
        onStateChanged()
    }

    override fun getCurrentState(): VpnManagerState {
        return state
    }

    override fun errorStub(error: PlatformErrorResponse) {
        TODO("Not yet implemented")
    }

    override fun close() {
        scope.cancel()
    }

    private fun onStateChanged() {
        eventSink?.success(state.ordinal)
    }

}