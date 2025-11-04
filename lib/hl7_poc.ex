defmodule Hl7Poc do
  use Application

  # Callback requis par le behaviour Application
  @impl true
  def start(_type, _args) do
    # Démarrer un superviseur simple
    children = []
    opts = [strategy: :one_for_one, name: Hl7Poc.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Lancer notre démo après le démarrage du superviseur
        run()
        {:ok, pid}

      error ->
        error
    end
  end

  def run do
    IO.puts("\n🌡️  Bienvenue dans le POC HL7 Parser en Elixir !")
    IO.puts("--------------------------------------------------")
    IO.puts("Ce POC va :\n")
    IO.puts("  1️⃣  Charger un fichier HL7 mocké")
    IO.puts("  2️⃣  Parser les segments")
    IO.puts("  3️⃣  Insérer les données dans Postgres")
    IO.puts("  4️⃣  Montrer un exemple de requête SQL\n")
    IO.puts("Démarrage en cours...\n")
    :timer.sleep(1000)

    # Démarrer Postgrex
    {:ok, _} = Application.ensure_all_started(:postgrex)

    pid = connect_db_with_retry()
    run_demo(pid)
  end

  defp connect_db_with_retry(retries \\ 10, delay \\ 2000) do
    opts = [
      hostname: "db",
      username: "demo",
      password: "demo",
      database: "hl7_demo",
      backoff_type: :stop
    ]

    IO.puts("🔌 Connexion à Postgres...")

    case Postgrex.start_link(opts) do
      {:ok, pid} ->
        IO.puts("✅ Connexion à Postgres réussie!")
        pid

      {:error, reason} when retries > 0 ->
        IO.puts("❌ Échec de connexion: #{inspect(reason)}")
        IO.puts("🔄 Nouvelle tentative dans #{delay}ms... (#{retries} restantes)")
        :timer.sleep(delay)
        connect_db_with_retry(retries - 1, delay)

      {:error, reason} ->
        IO.puts("💥 Échec définitif de connexion à la base de données: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_demo(pid) do
    # Vérifier que la connexion est active
    case Postgrex.query(pid, "SELECT 1", []) do
      {:ok, _} ->
        IO.puts("✅ Connexion vérifiée")

      {:error, reason} ->
        IO.puts("❌ La connexion n'est pas active: #{inspect(reason)}")
        System.halt(1)
    end

    # Chemin vers le fichier HL7
    path = Path.join("priv", "demo.hl7")
    IO.puts("\n📂 Lecture du fichier HL7 : #{path}")

    {:ok, data} = File.read(path)
    # HL7 utilise \r comme séparateur
    segments = String.split(data, "\r", trim: true)
    IO.puts("📊 #{length(segments)} segments détectés")

    # Afficher le parsing détaillé des segments
    IO.puts("\n🔍 PARSING DES SEGMENTS HL7 :")
    IO.puts(String.duplicate("=", 50))

    Enum.each(segments, fn segment ->
      parse_and_display_segment(segment)
    end)

    # Supprimer et recréer la table pour être sûr d'avoir la bonne structure
    IO.puts("\n🗃️  Création de la table...")

    # Supprimer la table si elle existe
    Postgrex.query!(
      pid,
      "DROP TABLE IF EXISTS hl7_segments",
      []
    )

    # Créer la table avec la nouvelle structure
    Postgrex.query!(
      pid,
      "CREATE TABLE hl7_segments (
        id serial PRIMARY KEY,
        segment_type varchar(3),
        content text,
        patient_id varchar(20),
        patient_name varchar(100),
        message_type varchar(10),
        created_at timestamp DEFAULT NOW()
      )",
      []
    )

    IO.puts(
      "✅ Table créée avec les colonnes: segment_type, content, patient_id, patient_name, message_type"
    )

    # Insérer les données avec parsing avancé
    IO.puts("💾 Insertion des données avec parsing...")

    for segment <- segments do
      {segment_type, patient_id, patient_name, message_type} = parse_segment_details(segment)

      IO.puts(
        "   Insertion segment: #{segment_type} - Patient: #{patient_id || "N/A"} - Message: #{message_type || "N/A"}"
      )

      Postgrex.query!(
        pid,
        "INSERT INTO hl7_segments (segment_type, content, patient_id, patient_name, message_type) VALUES ($1, $2, $3, $4, $5)",
        [segment_type, segment, patient_id, patient_name, message_type]
      )
    end

    IO.puts("\n✅ Données insérées dans la base")

    # Afficher des requêtes démonstratives
    IO.puts("\n🧠 REQUÊTES SQL DÉMONSTRATIVES :")
    IO.puts(String.duplicate("=", 50))

    # 1. Aperçu des segments
    IO.puts("\n1. 📋 Aperçu des 5 premiers segments :")
    result = Postgrex.query!(pid, "SELECT segment_type, content FROM hl7_segments LIMIT 5", [])

    Enum.each(result.rows, fn [type, content] ->
      IO.puts("   [#{type}] #{String.slice(content, 0, 60)}...")
    end)

    # 2. Statistiques par type de segment
    IO.puts("\n2. 📈 Statistiques par type de segment :")

    result =
      Postgrex.query!(
        pid,
        "SELECT segment_type, COUNT(*) FROM hl7_segments GROUP BY segment_type ORDER BY COUNT(*) DESC",
        []
      )

    Enum.each(result.rows, fn [type, count] ->
      IO.puts(
        "   #{String.pad_trailing(type, 5)}: #{String.pad_leading(to_string(count), 2)} segments"
      )
    end)

    # 3. Informations patients extraites
    IO.puts("\n3. 👤 Informations patients extraites :")

    result =
      Postgrex.query!(
        pid,
        "SELECT DISTINCT patient_id, patient_name FROM hl7_segments WHERE patient_id IS NOT NULL AND patient_name IS NOT NULL",
        []
      )

    if length(result.rows) > 0 do
      Enum.each(result.rows, fn [pid, name] ->
        IO.puts("   🆔 #{pid} : #{name}")
      end)
    else
      IO.puts("   ℹ️  Aucune information patient trouvée dans les segments PID")
    end

    # 4. Types de messages HL7
    IO.puts("\n4. 📨 Types de messages HL7 détectés :")

    result =
      Postgrex.query!(
        pid,
        "SELECT DISTINCT message_type FROM hl7_segments WHERE message_type IS NOT NULL",
        []
      )

    Enum.each(result.rows, fn [msg_type] ->
      IO.puts("   📧 #{msg_type}")
    end)

    # 5. Structure de la table
    IO.puts("\n5. 🗂️  Structure de la table hl7_segments :")

    result =
      Postgrex.query!(
        pid,
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'hl7_segments' ORDER BY ordinal_position",
        []
      )

    Enum.each(result.rows, fn [col_name, data_type] ->
      IO.puts("   #{String.pad_trailing(col_name, 15)} : #{data_type}")
    end)

    IO.puts("\n" <> String.duplicate("🎉", 10))
    IO.puts("   DÉMO TERMINÉE AVEC SUCCÈS !")
    IO.puts("   Données HL7 parsées et stockées dans PostgreSQL")
    IO.puts(String.duplicate("=", 50))
  end

  # Fonction pour parser et afficher un segment HL7 de manière détaillée
  defp parse_and_display_segment(segment) when byte_size(segment) > 0 do
    segment_type = String.slice(segment, 0, 3)

    case segment_type do
      "MSH" ->
        fields = String.split(segment, "|")
        IO.puts("\n🏥 SEGMENT MSH (Message Header):")
        IO.puts("   Type de message: #{Enum.at(fields, 8, "N/A")}")
        IO.puts("   Version HL7: #{Enum.at(fields, 11, "N/A")}")
        IO.puts("   ID message: #{Enum.at(fields, 9, "N/A")}")

      "PID" ->
        fields = String.split(segment, "|")
        patient_id = Enum.at(fields, 2, "")
        patient_name = Enum.at(fields, 5, "")
        IO.puts("\n👤 SEGMENT PID (Patient Identification):")
        IO.puts("   ID Patient: #{patient_id}")
        IO.puts("   Nom Patient: #{patient_name}")

      "PV1" ->
        fields = String.split(segment, "|")
        unit = Enum.at(fields, 3, "")
        room = Enum.at(fields, 3, "") |> String.split("^") |> Enum.at(1, "")
        IO.puts("\n🏨 SEGMENT PV1 (Patient Visit):")
        IO.puts("   Unité: #{unit}")
        IO.puts("   Chambre: #{room}")

      "OBR" ->
        fields = String.split(segment, "|")
        placer_order = Enum.at(fields, 2, "")
        universal_service = Enum.at(fields, 4, "")
        IO.puts("\n🔬 SEGMENT OBR (Observation Request):")
        IO.puts("   Ordre: #{placer_order}")
        IO.puts("   Service: #{universal_service}")

      "OBX" ->
        fields = String.split(segment, "|")
        value_type = Enum.at(fields, 2, "")
        observation = Enum.at(fields, 3, "")
        value = Enum.at(fields, 5, "")
        units = Enum.at(fields, 6, "")
        IO.puts("\n📊 SEGMENT OBX (Observation Result):")
        IO.puts("   Type: #{value_type}")
        IO.puts("   Observation: #{observation}")
        IO.puts("   Valeur: #{value} #{units}")

      _ ->
        IO.puts("\n📄 SEGMENT #{segment_type}:")
        IO.puts("   #{String.slice(segment, 0, 80)}...")
    end
  end

  defp parse_and_display_segment(_), do: nil

  # Fonction pour extraire les détails d'un segment pour la base de données
  defp parse_segment_details(segment) when byte_size(segment) > 0 do
    segment_type = String.slice(segment, 0, 3)
    fields = String.split(segment, "|")

    {patient_id, patient_name, message_type} =
      case segment_type do
        "MSH" ->
          {nil, nil, Enum.at(fields, 8, nil)}

        "PID" ->
          {Enum.at(fields, 2, nil), Enum.at(fields, 5, nil), nil}

        _ ->
          {nil, nil, nil}
      end

    {segment_type, patient_id, patient_name, message_type}
  end

  defp parse_segment_details(_), do: {nil, nil, nil, nil}
end
