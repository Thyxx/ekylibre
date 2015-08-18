# coding: utf-8
class LaGraineInformatique::Vinifera::ProductsExchanger < ActiveExchanger::Base

  def import
    
    # Unzip file
    dir = w.tmp_dir
    Zip::File.open(file) do |zile|
      zile.each do |entry|
        entry.extract(dir.join(entry.name))
      end
    end
    
    rows = CSV.read(file, headers: true, encoding: 'cp1252', col_sep: ';')
    w.count = rows.count

    variants_transcode = {}.with_indifferent_access
    path = dir.join('variants_transcode.csv')
    if path.exist?
      CSV.foreach(path, headers: true) do |row|
        variants_transcode[row[0]] = row[1].to_sym
      end
    end

    units_transcode = {}.with_indifferent_access
    measures_transcode = {}.with_indifferent_access
    path = dir.join('units_transcode.csv')
    if path.exist?
      CSV.foreach(path, headers: true) do |row|
        units_transcode[row[0]] = row[1].to_s
        measures_transcode[row[0]] = Measure.new(row[2], row[3].to_sym)
      end
    end

    # FILE STRUCTURE
    # 0 CATEGORY (F or P)
    # 1 Appelation ( to transcode )
    # 2 year (2digit)
    # 3 unity for sale (to transcode)
    # number of variant (1-2-3)
    # 4 name (first line)
    # 5 name (second line)
    # 6 name (third line)
    # 7 familly
    # 12 manage lot (O/N)
    # 13 manage stock (O/N)
    # 15 initial stock
    # 43 (pdtpxv01) - first sale price (link to catalog)
    # to
    # 72 (pdtpxv30) - 30th sale price

    rows.each do |row|
      r = {
          appelation: row[1].blank? ? nil : row[1].to_s,
          millesime: row[2].blank? ? nil : row[2].to_s,
          unity: row[3].blank? ? nil : row[3].to_s,
          name: row[4].blank? ? nil : row[4].to_s,
          complement_name_1: row[5].blank? ? nil : row[5].to_s,
          complement_name_2: row[6].blank? ? nil : row[6].to_s
      }.to_struct

      number = r.appelation + "-" + r.year + "-" + r.unity if r.appelation && r.year && r.unity

      if number
        # find variant in DB by number
        unless variant = ProductNatureVariant.find_by_number(number)
          # or import variant in DB by transcoding number from NOMENCLATURE
          variant = ProductNatureVariant.import_from_nomenclature(variants_transcode[number]) if variants_transcode[number]
          variant.number = number
          variant.name = r.name if r.name
          variant.description = r.complement_name_1 if r.complement_name_1
          variant.unit_name = units_transcode[r.unity] if r.unity
          variant.save!
        end
      end
      w.check_point
    end
  end
end