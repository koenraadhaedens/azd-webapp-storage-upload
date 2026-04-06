"""
Runtime flow diagram for the Secure OTP-Gated File Upload Portal.
Shows the OTP request flow and file upload flow at runtime.
Generates: scenario/secure-upload-portal/03-architect-runtime-diagram.png
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.azure.compute import AppServices
from diagrams.azure.storage import BlobStorage
from diagrams.azure.integration import LogicApps
from diagrams.azure.monitor import ApplicationInsights
from diagrams.azure.identity import ManagedIdentities as ManagedIdentity
from diagrams.onprem.client import User
from diagrams.azure.integration import LogicApps as Postfix

graph_attr = {
    "bgcolor": "white",
    "pad": "1.0",
    "nodesep": "1.0",
    "ranksep": "1.2",
    "splines": "ortho",
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
    "bgcolor": "#f9f9f9",
}

flow_style = {
    "margin": "20",
    "fontname": "Arial Bold",
    "fontsize": "12",
    "bgcolor": "#eaf4ff",
    "style": "rounded",
}

with Diagram(
    "Runtime Flow — OTP Auth + File Upload",
    filename="scenario/secure-upload-portal/03-architect-runtime-diagram",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    n_user = User("User\n(Browser)")

    with Cluster("Azure — rg-secureupload-dev", graph_attr=cluster_style):

        with Cluster("OTP Flow", graph_attr=flow_style):
            n_app_email = AppServices("App Service\n/ (Email Entry)")
            n_app_verify = AppServices("App Service\n/verify (OTP Check)")
            n_logic = LogicApps("Logic App\nConsumption")
            n_email_dest = User("User Inbox\n(Office 365)")

        with Cluster("Upload Flow", graph_attr=flow_style):
            n_app_upload = AppServices("App Service\n/upload (File Upload)")
            n_mi = ManagedIdentity("Managed Identity\nBlob Contributor")
            n_storage = BlobStorage("Blob Storage\n(uploads container)")

        n_appi = ApplicationInsights("App Insights\nTelemetry")

    # OTP flow
    n_user >> Edge(label="1. POST email", color="#1565C0") >> n_app_email
    n_app_email >> Edge(label="2. POST {email, otp}\n(SAS URL)", color="#E65100") >> n_logic
    n_logic >> Edge(label="3. Send Email\n(O365 connector)", color="#E65100") >> n_email_dest
    n_email_dest >> Edge(label="4. OTP email\ndelivered", color="#2E7D32", style="dashed") >> n_user
    n_user >> Edge(label="5. POST otp", color="#1565C0") >> n_app_verify
    n_app_verify >> Edge(label="6. Session validated\n→ redirect /upload", color="#2E7D32", style="dashed") >> n_user

    # Upload flow
    n_user >> Edge(label="7. POST file", color="#1565C0") >> n_app_upload
    n_app_upload >> Edge(label="8. Acquire token\n(DefaultAzureCredential)", color="#6A1B9A", style="dashed") >> n_mi
    n_mi >> Edge(label="9. Stream blob\n(private endpoint)", color="#388E3C") >> n_storage
    n_storage >> Edge(label="10. Blob URI\nreturned", color="#388E3C", style="dashed") >> n_app_upload
    n_app_upload >> Edge(label="11. Success\nconfirmation", color="#2E7D32", style="dashed") >> n_user

    # Telemetry
    n_app_email >> Edge(label="telemetry", color="#90A4AE", style="dashed") >> n_appi
    n_app_upload >> Edge(label="telemetry", color="#90A4AE", style="dashed") >> n_appi
