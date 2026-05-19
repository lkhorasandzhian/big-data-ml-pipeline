import os

jupyterhub_user = os.environ["JUPYTERHUB_USER"]

c.Authenticator.allowed_users = {jupyterhub_user}
c.Authenticator.admin_users = {jupyterhub_user}

c.Spawner.default_url = "/lab"
c.Spawner.notebook_dir = f"/home/{jupyterhub_user}/work"