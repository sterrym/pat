load 'lib/nil_class.rb'

Time.class_eval do 
  def <=>(other)
    if other.nil?
      -1
    else
      self - other
    end
  end
end

DateTime.class_eval do 
  def <=>(other)
    if other.nil?
      -1
    else
      self - other
    end
  end
end

Time.class_eval do 
  def <=>(other)
    if other.nil?
      -1
    else
      self - other
    end
  end
end
