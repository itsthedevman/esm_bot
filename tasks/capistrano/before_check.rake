namespace :deploy do
  before :check, :update_env do
    on roles(:app) do |host|
      admin_repo = "/home/wolf/esm_bot_admin"

      # Make sure the folder exists and the code has been cloned
      if !test "[ -d #{admin_repo} ]"
        execute("cd /home/wolf && git clone esm_bot_admin:itsthedevman/esm_bot_admin.git")
      end

      # Pull any updates
      execute("cd #{admin_repo} && git pull")

      if !test "[ -d /home/wolf/esm_bot/shared ]"
        execute("mkdir -p /home/wolf/esm_bot/shared")
      end

      # Copy the files to shared
      execute("ln -sf #{admin_repo}/env.prod /home/wolf/esm_bot/shared/.env.prod")
    end
  end
end
