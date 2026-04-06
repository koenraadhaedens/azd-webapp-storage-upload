"""
Architecture diagram for the Secure OTP-Gated File Upload Portal.
Generates: scenario/secure-upload-portal/03-architect-diagram.png
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.azure.compute import AppServices
from diagrams.azure.storage import BlobStorage
from diagrams.azure.network import VirtualNetworks, Subnets, PrivateEndpoint
from diagrams.azure.integration import LogicApps
from diagrams.azure.monitor import ApplicationInsights, LogAnalyticsWorkspaces
from diagrams.azure.identity import ManagedIdentities as ManagedIdentity
from diagrams.onprem.client import User

graph_attr = {
    "bgcolor": "white",
    "pad": "1.0",
    "nodesep": "0.9",
    "ranksep": "1.0",
    "splines": "spline",
    "fontname": "Arial Bold",
    "fontsize": "16",
    "dpi": "150",
}

node_attr = {
    "fontname": "Arial Bold",
    "fontsize": "11",
    "labelloc": "t",
}

cluster_style = {
    "margin": "30",
    "fontname": "Arial Bold",
    "fontsize": "13",
    "bgcolor": "#f5f5f5",
}

vnet_style = {
    "margin": "30",
    "fontname": "Arial Bold",
    "fontsize": "13",
    "bgcolor": "#e8f4f8",
    "style": "dashed",
}

subnet_style = {
    "margin": "20",
    "fontname": "Arial",
    "fontsize": "11",
    "bgcolor": "#def0f8",
    "style": "dotted",
}

with Diagram(
    "Secure OTP-Gated File Upload Portal",
    filename="scenario/secure-upload-portal/03-architect-diagram",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    n_ext_user = User("End User\n(Browser)")

    with Cluster("rg-secureupload-dev  |  eastus2", graph_attr=cluster_style):

        with Cluster("vnet-secureupload-dev  (10.0.0.0/16)", graph_attr=vnet_style):

            with Cluster("snet-appservice-dev  (10.0.1.0/24)", graph_attr=subnet_style):
                n_web_app = AppServices("app-secureupload-dev\n.NET 10 Razor Pages")
                n_id_mi = ManagedIdentity("System-Assigned\nManaged Identity")

            with Cluster("snet-privateep-dev  (10.0.2.0/24)", graph_attr=subnet_style):
                n_net_pe = PrivateEndpoint("pe-storage-blob\nBlob subresource")

        n_data_storage = BlobStorage("stsecureupload{suffix}\nStandard LRS\nPublic Access: Off")
        n_int_logic = LogicApps("logic-secureupload-dev\nConsumption\nO365 Email Trigger")

        with Cluster("Observability", graph_attr=cluster_style):
            n_ops_law = LogAnalyticsWorkspaces("log-secureupload-dev")
            n_ops_appi = ApplicationInsights("appi-secureupload-dev")

    n_ext_user >> Edge(label="HTTPS", color="#1565C0") >> n_web_app
    n_web_app >> Edge(label="VNet Integrated", color="#1565C0", style="dashed") >> n_net_pe
    n_net_pe >> Edge(label="Private Link", color="#388E3C") >> n_data_storage
    n_web_app >> Edge(label="Managed Identity\nBlob Contributor", color="#6A1B9A", style="dashed") >> n_id_mi
    n_id_mi >> Edge(label="RBAC Auth", color="#6A1B9A", style="dashed") >> n_data_storage
    n_web_app >> Edge(label="HTTPS POST\n(SAS URL)", color="#E65100") >> n_int_logic
    n_web_app >> Edge(label="Telemetry", color="#37474F", style="dashed") >> n_ops_appi
    n_ops_appi >> Edge(label="Logs + Metrics", color="#37474F", style="dashed") >> n_ops_law
    n_data_storage >> Edge(label="Diagnostics", color="#37474F", style="dashed") >> n_ops_law
