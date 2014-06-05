# OAuth extension for User model
#
# * Find GitLab user based on omniauth uid and provider
# * Create new user from omniauth data
#
module Gitlab
  module OAuth
    class User
      class << self
        attr_reader :auth

        def find(auth)
          @auth = auth
          find_by_uid_and_provider
        end

        def create(auth)
          @auth = auth
          password = Devise.friendly_token[0, 8].downcase
          opts = {
            extern_uid: uid,
            provider: provider,
            name: name,
            username: username,
            email: email,
            password: password,
            password_confirmation: password,
          }

          user = model.build_user(opts, as: :admin)
          user.skip_confirmation!
          user.save!
          log.info "(Oauth:#{provider}) Creating user '#{username}' with mail '#{email}' from login with extern_uid => #{uid}"

          if Gitlab.config.omniauth['block_auto_created_users'] && !ldap?
            user.block
          end

          user
        end

        private

        def find_by_uid_and_provider
          model.where(provider: provider, extern_uid: uid).last
        end

        def uid
          auth.info.uid || auth.uid
        end

        def email
          auth.info.email.downcase unless auth.info.email.nil?
        end

        def name
          auth.info.name.to_s.force_encoding("utf-8")
        end

        def username
          uname = uid.gsub('@','.') || email.match(/^[^@]*/)[0]
          
          if ldap? && !ldap_uid.nil?
            uname = ldap_uid.gsub('@','.') 
          end
          
          uname
        end

        def provider
          auth.provider
        end

        def log
          Gitlab::AppLogger
        end

        def model
          ::User
        end

        def raise_error(message)
          raise OmniAuth::Error, "(OAuth) " + message
        end

        def ldap?
          provider == 'ldap'
        end
        
        def ldap_uid
          auth.extra.raw_info[ldap_uid_field].first unless !ldap?
        end
        
        def ldap_uid_field
          Gitlab.config.ldap.uid || 'samaccountname'
        end
      end
    end
  end
end
