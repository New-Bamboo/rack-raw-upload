class User < ActiveRecord::Base

  mount_uploader :thing, ThingUploader

end
