Rails.application.config.session_store :active_record_store, key: '_operation_boost_session',
                                                             secure: Rails.env.production?
