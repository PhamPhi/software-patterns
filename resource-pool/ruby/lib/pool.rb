require "thread"

# Public: A thread-safe resource pool.
#
class Pool

  class Error < StandardError; end

  # An error indicating a given resource is busy.
  class ResourceBusy < Error; end

  # An error indicating a given resource is not found.
  class NotFound < Error; end

  # You performed an invalid action.
  class InvalidAction < Error; end

  # Default all methods to private. See the bottom of the class definition for
  # public method declarations.
  private

  # Public: initialize a new pool.
  #
  # max_size - if specified, limits the number of resources allowed in the pool.
  def initialize(max_size=nil)
    # Available resources
    @available = Hash.new
    # Busy resources
    @busy = Hash.new

    # The pool lock
    @lock = Mutex.new

    @full_lock = Mutex.new
    @full_cv = ConditionVariable.new

    # Maximum size of this pool.
    @max_size = max_size
  end # def initialize

  # Private: Is this pool size-limited?
  #
  # Returns true if this pool was created with a max_size. False, otherwise.
  def sized?
    return !@max_size.nil?
  end # def sized?

  # Private: Is this pool full?
  #
  # Returns true if the pool is sized and the count of resources is at maximum.
  def full?
    return sized? && (count == @max_size)
  end # def full?

  # Public: the count of resources in the pool
  #
  # Returns the count of resources in the pool.
  def count
    return (@busy.size + @available.size)
  end # def count

  # Public: Add a new resource to this pool.
  #
  # The resource, once added, is assumed to be available for use.
  # That means once you add it, you must not use it unless you receive it from
  # {Pool#fetch}
  #
  # resource - the object resource to add to the pool.
  #
  # Returns nothing
  def add(resource)
    @lock.synchronize do
      @available[resource.object_id] = resource
    end
    return nil
  end # def add

  # Public: Fetch an available resource.
  #
  def fetch(&default_value_block)
    @lock.synchronize do
      object_id, resource = @available.shift
      if !resource.nil?
        @busy[resource.object_id] = resource
        return resource
      end
    end

    @full_lock.synchronize do
      if full?
        # This should really use a logger.
        puts "=> Pool is full and nothing available. Waiting for a release..."
        @full_cv.wait(@full_lock)
        return fetch(&default_value_block)
      end
    end

    # If we get here, no resource is available and the pool is not full.
    resource = default_value_block.call
    # Only add the resource if the default_value_block returned one.
    if !resource.nil?
      add(resource)
      return fetch
    end
  end # def fetch

  # Public: Remove a resource from the pool.
  #
  # This is useful if the resource is no longer useful. For example, if it is
  # a database connection and that connection has failed.
  #
  # This resource *MUST* be available and not busy.
  #
  # Raises Pool::NotFound if no such resource is found.
  # Raises Pool::ResourceBusy if the resource is found but in use.
  def remove(resource)
    # Find the object by object_id
    #p [:internal, :busy => @busy, :available => @available]
    @lock.synchronize do
      #p resource.object_id => include?(resource)
      if available?(resource)
        raise InvalidAction, "This resource must be busy for you to remove it (ie; it must be fetched from the pool)"
      end

      @busy.delete(resource.object_id)
    end
  end # def remove

  # Private: Verify this resource is in the pool.
  #
  # You *MUST* call this method only when you are holding @lock.
  def include?(resource)
    if @available.include?(resource.object_id)
      return :available
    elsif @busy.include?(resource.object_id)
      return :busy
    else
      return false
    end
  end # def include?

  #
  # You *MUST* call this method only when you are holding @lock.
  def available?(resource)
    case include?(resource)
      when :available; return true
      when :busy; return false
      else; raise NotFound, "No resource, #{resource.inspect}, found in pool"
    end
  end # def avilable?

  # Private: Is this resource busy?
  #
  # You *MUST* call this method only when you are holding @lock.
  #
  # Returns true if this resource is busy.
  def busy?(resource)
    return !available?(resource)
  end # def busy?

  # Private: Mark this resource as in use
  def mark(resource)
    @lock.synchronize do
      if !available?(resource)
        raise ResourceBusy, "The resource is already busy (in use), cannot mark. Resource; #{resource.inspect}"
      end

      @available.delete(resource.object_id)
      @busy[resource.object_id] = resource
    end
  end # def mark

  def release(resource)
    @lock.synchronize do
      if !include?(resource)
        raise NotFound, "No resource, #{resource.inspect}, found in pool"
      end

      # Release is a no-op if this resource is already available.
      #return if available?(resource)
      @busy.delete(resource.object_id)
      @available[resource.object_id] = resource

      # Notify any threads waiting on a resource from the pool.
      @full_lock.synchronize { @full_cv.signal }
    end
  end # def release

  public(:add, :remove, :fetch, :release, :sized?, :count)
end # def Pool
