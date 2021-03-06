# encoding: utf-8 
class OrganizationsController < ApplicationController

  helper_method :sort_column, :sort_direction
  include GraphHelper 
  include ApplicationHelper
  include QueryHelper

  BOM = "\uFEFF" #Byte Order Mark

  def getSuppliers
    @suppliers = []
    if params[:term]
      @suppliers = Organization.where("is_bidder = true AND name LIKE ?", "%#{params[:term]}%")
    end
 
    puts "WTTF"
    render :json => @suppliers.map(&:name)
  end

  def getProcurers
    @procurers = []
    if params[:term]
      @procurers = Organization.where("is_procurer = true AND name LIKE ?", "%#{params[:term]}%")
    end

    puts "WWTF"
    render :json => @procurers.map(&:name)
  end

  def search
    @params = params

    results, searchParams = QueryHelper.buildSupplierSearchQuery(params)   
    @numResults = results.count
    @organizations = results.paginate(:page => params[:page]).order(sort_column + ' ' + sort_direction)

    @searchType = "supplier" 
    checkSavedSearch(searchParams, @searchType)
    @sort = params[:sort]
    @direction = params[:direction]
    respond_to do |format|
      format.html
      format.csv {   
        sendCSV(results, "organizations")
      }
    end 
  end

  def sendCSV( results, name )
    csv_data = CSV.generate() do |csv|
      csv << ["Name","Country","Legal Type","City","Address","Phone Number","Fax Number","Email","Web Page","Code"]
      results.each do |org|
       csv << [org.name,org.country,org.org_type,org.city,org.address,org.phone_number,org.fax_number,org.email,
               org.webpage,org.code]
      end
    end

    filename = name+".csv"
    content = BOM + csv_data
    send_data content, :filename => filename
  end

  def search_procurer
    @params = params
    results, searchParams = QueryHelper.buildProcurerSearchQuery(params)
    @numResults = results.count
    @organizations = results.paginate( :page => params[:page]).order(sort_column + ' ' + sort_direction)

    @searchType = "procurer"
    @sort = params[:sort]
    @direction = params[:direction]
    checkSavedSearch(searchParams, @searchType)
    respond_to do |format|
      format.html
      format.csv {        
        sendCSV(results, "procurers")
      }
    end 
  end

  def show_procurer
    id = params[:id]
    @organization = Organization.find(id)

    @isWatched = false
    tendersToHighlight = []
    if current_user
      watched_procurers = current_user.procurer_watches
      watches = ProcurerWatch.where(:user_id => current_user.id, :procurer_id => id)
      watches.each do |watched|
        @isWatched = true
        @procurer_watch_id = watched.id
        if params[:highlights] and watched.has_updated
          changes = watched.diff_hash.split("#")
          changes.each do |change|
            index = change.index("tender")
            if index
              tendersToHighlight.push(change[0..index-1])
            end
          end
        end
        #reset the update flag to false since this procurer has now been viewed
        watched.has_updated = false
        watched.save
      end
    end

    tenders = Tender.find_all_by_procurring_entity_id(id)
    @numTenders = tenders.count
    @totalEstimate = 0
    @actualCost = 0
    totalBids = 0
    totalBidders = 0
    @numAgreements = 0
    @numActiveTenders = 0
    @numFailedAgreements = 0
    @averageTenderDurationSimple = 0;
    @averageTenderDurationElectronic = 0;
    failedStatuses = ["დასრულებულია უარყოფითი შედეგით","ტენდერი არ შედგა","ტენდერი შეწყვეტილია"]
    tendersPerCpv = {}
    @tendersOffered = []
    tenders.each do |tender|
      cpvDescription = TenderCpvClassifier.where(:cpv_code => tender.cpv_code).first.description_english
      if cpvDescription == nil
        cpvDescription = "NA"
     end
      tender[:cpvDescription] = cpvDescription
      if tender.inProgress
       tender[:status] = "active"
      elsif failedStatuses.include?(tender.tender_status)    
       tender[:status] = "failed"
      else
        tender[:status] = "success"
      end
      @tendersOffered.push(tender)

      if tendersPerCpv[tender.cpv_code]
        tendersPerCpv[tender.cpv_code][1] += 1
      else
        tendersPerCpv[tender.cpv_code] = [cpvDescription, 1 ]
      end

      if tendersToHighlight.include?(tender.id.to_s)
        tender[:highlight] = true
      end  
    end

    tendersPerCpv = tendersPerCpv.sort { |a,b| b[1][1] <=> a[1][1]}
    @Cpvs = []
    tendersPerCpv.each do |key, value|
      @Cpvs.push( value )
    end
    @successfulTenders = {}
    #lets get some aggregate tender stats
    @averageTenderDurationSimple = 0
    simpleCount = 0
    @averageTenderDurationElectronic = 0
    electronicCount = 0

    @tendersOffered.each do |tender|
      if tender[:status] == "success"
        value = 0
        if tender.contract_value
          value = tender.contract_value
        end
        @actualCost += value
        @totalEstimate += tender.estimated_value
        @numAgreements += 1
        date = tender.tender_announcement_date.to_time.to_i/86400
        if tender.tender_type.strip == "გამარტივებული ელექტრონული ტენდერი"
          @averageTenderDurationSimple += (tender.bid_end_date - tender.tender_announcement_date).to_i
          simpleCount+=1
        elsif tender.tender_type.strip == "ელექტრონული ტენდერი"
          @averageTenderDurationElectronic += (tender.bid_end_date - tender.tender_announcement_date).to_i
          electronicCount+=1
        end

        if not @successfulTenders[date]
          @successfulTenders[date] = [tender, value]
        else
          #this tender was announced on the same day as another tender and we can only go as far as per day on the graph
          #so lets pick the most important tender and ignore the other one :(
          old = @successfulTenders[date]
          if old[0].estimated_value < tender.estimated_value
            #overwrite old data
            @successfulTenders[date] = [tender, value]
          end
        end
      elsif tender[:status] == "active"
        @numActiveTenders += 1
      else
        @numFailedAgreements+= 1
      end

      totalBids += tender.num_bids
      totalBidders += tender.num_bidders
    end

    tenderList = Tender.where("procurring_entity_id = "+id.to_s+" AND winning_org_id IS NOT NULL" )
    createTreeGraph(tenderList)

    @successfulTenders = @successfulTenders.sort{|a,b| a[0] <=> b[0]}
    if simpleCount > 0
      @averageTenderDurationSimple = @averageTenderDurationSimple.to_f / simpleCount
    else
      @averageTenderDurationSimple = -1
    end
    if electronicCount > 0 
      @averageTenderDurationElectronic = @averageTenderDurationElectronic.to_f / electronicCount
    else
      @averageTenderDurationElectronic = -1
    end

    #time for tasty averages
    @averageBids = totalBids.to_f/@numTenders
    @averageBidders = totalBidders.to_f/@numTenders
    costString = "N/A"
    if @totalEstimate > 0
      costString = "%.1f" % ((1-@actualCost/@totalEstimate)*100)
    end
    @costVsEstimateSaving = costString
  end
                          
  def download_proc_tenders
    respond_to do |format|
      format.csv{
        tenders = Tender.find_all_by_procurring_entity_id(params[:id])
        send_data buildTenderCSVString(tenders)
      }
    end
  end

  def download_org_tenders
    respond_to do |format|
      format.csv{   
        allBids = Bidder.find_all_by_organization_id(params[:id])
        tenders = []
        allBids.each do |bid|
          tender = Tender.find(bid.tender_id)
          tenders.push(tender)
        end

        send_data buildTenderCSVString(tenders)
      }
    end
  end
  

  def show
    id = params[:id]
    @organization = Organization.find(id)
    @isWatched = false
    tendersToHighlight = []

    if current_user
      watched_suppliers = current_user.supplier_watches
      watches = SupplierWatch.where(:user_id => current_user.id, :supplier_id => id)
      watches.each do |watched|
        @isWatched = true
        @supplier_watch_id = watched.id
        if params[:highlights] and watched.has_updated
          changes = watched.diff_hash.split("#")
          changes.each do |change|
            #maybe extend this functionality later to deal with bids and agreements differently
            index = change.index("bid")
            if index
              tendersToHighlight.push(change[0..index-1])
            else
              index = change.index("agreement")
              if index
                tendersToHighlight.push(change[0..index-1])
              end
            end
          end
        end

        #reset the update flag to false since this procurer has now been viewed
        watched.has_updated = false
        watched.save
      end
    end

    @blackListed = false
    @whiteListed = false
    if WhiteListItem.where("organization_id = ?",id).count > 0
      @whiteListed = true
    end
    if BlackListItem.where("organization_id = ?",id).count > 0
      @blackListed = true
    end

    localeStr = "ka"
    if I18n.locale == :en
      localeStr = "en"
    end
    if @organization.country == "საქართველო"
      @corpsearchurl = "http://corpsearch.tigeorgia.webfactional.com/"+localeStr+"/corporations/search/?id_code="+@organization.code.to_s
    else
      @corpsearchurl = "http://opencorporates.com/companies?utf8=%E2%9C%93&q="+@organization.code.to_s+"&commit=Go"
    end

    allBids = Bidder.find_all_by_organization_id(id)
    allTenders = []
    @topFiveCpvs = []
    tendersPerCpv = {}
    allBids.each do |bid|
      tender = Tender.find(bid.tender_id)
      allTenders.push(tender)
      if tendersPerCpv[tender.cpv_code]
        tendersPerCpv[tender.cpv_code] += 1
      else
        tendersPerCpv[tender.cpv_code] = 1
      end
    end
    
    tendersPerCpv = tendersPerCpv.sort { |a,b| b[1] <=> a[1]}
    @topFiveCpvs = []
    count = 0
    tendersPerCpv.each do |key, value|
      count = count + 1
      if count > 50
        break
      end
      description = TenderCpvClassifier.where(:cpv_code => key).first.description_english
      @topFiveCpvs.push( [description,value] )
    end 
    
    tendersWon = {}
    tenderList = Tender.where(:winning_org_id => id)
    tenderList.each do |tender|
      tendersWon[tender.id] = [tender.contract_value,tender]
    end

    createTreeGraph(tenderList)

    #find all competitors
    @competitors = []
    org_competitors = Competitor.where("organization_id = ?",id) 
    org_competitors.each do | competitor |
      info = []
      info.push(Organization.find(competitor.rival_org_id))
      info.push(competitor.num_tenders)
      @competitors.push( info )
    end

    @numTenders = allTenders.count
    @numTendersWon = tendersWon.size
    @numTendersLost = 0
    @numTendersInProgress = 0
    @WLR = @numTendersWon.to_f()/@numTenders.to_f()
    @totalValueOfAllContracts = 0
    @totalEstimatedValueOfContractsWon = 0
    @averageNumBiddersOnContractsWon = 0
    procuringEntities = {}
    tendersWon.each do |key, tender|
      @totalValueOfAllContracts += tender[0]
      @totalEstimatedValueOfContractsWon += tender[1].estimated_value
      @averageNumBiddersOnContractsWon += tender[1].bidders.count
      procuringID = tender[1].procurring_entity_id
      if procuringEntities[procuringID]
        procuringEntities[procuringID] += 1
      else
        procuringEntities[procuringID] = 1
      end
    end

    procuringEntities = procuringEntities.sort { |a,b| b[1] <=> a[1]}
    @topTenProcuringEntities = []
    count = 0

    procuringEntities.each do |key, value|
      count = count + 1
      if count > 50
        break
      end
      @topTenProcuringEntities.push( [Organization.find(key), value] )
    end

    @EstimatedVActual = 0
    if @numTendersWon > 0
      @averageNumBiddersOnContractsWon = @averageNumBiddersOnContractsWon.to_f / @numTendersWon.to_f
      @EstimatedVActual = (@totalValueOfAllContracts/@totalEstimatedValueOfContractsWon) * 100
    end

    @tenderInfo = []
    #create a hash with tasty info
    allTenders.each do |tender|
      tenderDuration = (tender.bid_end_date - tender.bid_start_date).to_i
      infoItem = { :id => tender.id, :tenderCode => tender.tender_registration_number, :numBidders => tender.bidders.count, :bidDuration => tenderDuration, :highest_bid => nil, :lowest_bid => nil, :numBids => nil, :start_amount => tender.estimated_value, :won => false, :procurerName => nil, :procurerID => tender.procurring_entity_id, :tenderAnnouncementDate => tender.tender_announcement_date, :contract_value => tender.contract_value, :highlight => false}
      infoItem[:procurerName] = Organization.find(tender.procurring_entity_id).name
      if tendersWon[tender.id]
        infoItem[:status] = "won"
      elsif tender.inProgress
        infoItem[:status] = "in progress"   
        @numTendersInProgress += 1
      else
        infoItem[:status] = "lost"
        @numTendersLost += 1
      end

      if tendersToHighlight.include?(tender.id.to_s)
        infoItem[:highlight] = true
      end

      allBids.each do |bid|
        if bid.tender_id == tender.id
          infoItem[:highest_bid] = bid.first_bid_amount
          infoItem[:lowest_bid] = bid.last_bid_amount
          infoItem[:numBids] = bid.number_of_bids
          break
        end
      end
      @tenderInfo.push(infoItem)
    end
    @tenderInfo.sort! { |a,b| (a[:status] == "won" ? -1 : 1) }
    tendersWon = tendersWon.sort { |a,b| a[1][1].tender_announcement_date <=> b[1][1].tender_announcement_date }

    @simpleTenderStats = {}
    @TenderStats = {}
    tendersWon.each do |key,tenderItem|
      tender = tenderItem[1]
      date = tender.tender_announcement_date.to_time.to_i/86400
      dateStats = @TenderStats
      if tender.tender_type.strip == "გამარტივებული ელექტრონული ტენდერი"
        dateStats = @simpleTenderStats
      end
      if not dateStats[date]
        dateStats[date] = [tender, tenderItem[0]]
      else
        #this tender was announced on the same day as another tender and we can only go as far as per day on the graph
        #so lets pick the most important tender and ignore the other one :(
        old = dateStats[date]
        if old[0].estimated_value < tender.estimated_value
          #overwrite old data
          dateStats[date] = [tender, tenderItem[0]]
        end
      end
    end
  end


  private
  def createTreeGraph(tenders)
    cpvAgreements = {}
    tenders.each do |tender|
      if tender.sub_codes   
        codes = tender.sub_codes.split("#")
        codes.each do |code|
          cpvCode = TenderCpvClassifier.where(:cpv_code => code).first
          if not cpvCode
            puts "code not found: #{code}"
            cpvDescription = nil
          else
            if I18n.locale == :en
              cpvDescription = cpvCode.description_english
            else
              cpvDescription = cpvCode.description
            end
          end
          if cpvDescription == nil
            cpvDescription = "NA"
          end
          item = { :name => cpvDescription, :value => tender.contract_value.to_f/codes.length, :code => code, :children => [] }
          if cpvAgreements[code]
            val = cpvAgreements[code][:value]
            item[:value] += val
          end
          cpvAgreements[code] = item
        end
      end
    end
    @jsonString = GraphHelper.createTreeGraphStringFromAgreements( cpvAgreements )
  end

  def sort_column
    params[:sort] || "name"
  end

  def sort_direction
    params[:direction] || "asc"
  end

end
