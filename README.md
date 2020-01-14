# 概要
AWS 上で Git LFS をホスティングするための Terraform スクリプトです。

# 解説
* API Gateway + Lambda + S3 によるサーバーレスで構築します。
* 他のソリューション (GitHub LFS) に比べて以下のメリットがあります。
    * 容量が足りなくなるたびに追加パッケージを購入する必要がない
    * ストレージ・転送費用が AWS アカウント毎に算出できる
    * 費用
* LFS サーバーには LFS Batch(v2) プロトコルに対応している [Estranged.Lfs](Estranged.Lfs|https://github.com/alanedwardes/Estranged.Lfs) を採用し、これを Lambda にデプロイします。
現時点では 2.1.0 をリポジトリ内 (./lambda) に含めています。バージョンを変更する場合は [こちら](https://github.com/alanedwardes/Estranged.Lfs/releases) から任意の Zip をダウンロードして入れ替えてください。
なお、ソースコードを修正する場合は、最新の .NET Core SDK が入っている環境で以下のコマンドからビルド成果物を作成し、Zip アーカイブすれば OK です。

    ```bash
    dotnet publish hosting/Estranged.Lfs.Hosting.Lambda/Estranged.Lfs.Hosting.Lambda.csproj -c Release -o dist /p:GenerateRuntimeConfigurationFiles=true
    ```

* API Gateway はリソースポリシーで IP 制限をかける前提です。
最初 WAF で制限かけようとしてたのですが、Terraform が [対応中](https://github.com/terraform-providers/terraform-provider-aws/pull/7205) で使えなかったので諦めました。

* データは全て S3 に保存されます。このデータは以下の特徴があります。
    * ファイルはハッシュ名で保存される。つまりファイルハッシュ毎にファイルが保存される。
    * API は download と upload しかない。つまり一度作成されたファイルは S3 で直接消さない限り、二度と消すことができない。

* この TF スクリプトは [こちらのサイト](https://alanedwardes.com/blog/posts/serverless-git-lfs-for-game-dev/) にある CloudFormation 用の yaml を参考にしています。
この yaml は eu-west-1 の S3 に存在する Lambda パッケージをハードコードで指定していることが原因で他のリージョンで構築できないため、全て Terraform で書き直しました。

# 環境構築前準備
以下の変数を設定します (variable.tf)
* name: AWS リソースにつく名称のプレフィックス
* profile: AWS Profile
* region: AWS リージョン
* gitlfs_s3_bucket: ストレージ保存先となる S3 バケット名
* gitlfs_username: API Gateway への Basic 認証用ユーザー名
* gitlfs_password: API Gateway への Basic 認証用パスワード
* gitlfs_allow_ips: API Gateway への IP制限をかけるためのホワイトリスト (CIDR)

# 環境構築が終わったら
* terraform apply が成功すると Basic 認証付きの URL が Output として吐かれるので、この URL を .lfsconfig に設定して利用します。

    ```
    [lfs]
        url = https://{gitlfs_username}:{gitlfs_password}@{api-id}.execute-api.{region}.amazonaws.com/lfs
    ```

# LFS の運用
* まずは [チュートリアル](https://github.com/git-lfs/git-lfs/wiki/Tutorial) があるので確認しておくと良いと思います。
* 既存の GIT リポジトリからの移行には `git lfs migrate` コマンドを使うことを推奨します。
これは過去履歴の書き換えと .gitattributes の生成を行います。
この過去履歴の書き換えによって .git フォルダ内に残る過去履歴の中から移行対象ファイルを消すことができるので動作が軽くなります。
履歴改ざんを伴うため強制プッシュ (git push -f) が必要になることがあります。
* 通常 git clone した時点で LFS からもファイルが降ってきます。高速化・容量逼迫回避などの目的でこれをスキップさせるには GIT_LFS_SKIP_SMUDGE 環境変数に 1 を指定してから git clone するか、あるいは以下の設定をしてください。

    ```bash
    git config filter.lfs.smudge "git-lfs smudge --skip %f"
    ```

* LFS 化したファイルを GitHub 上で確認するとポインタファイルに置き換わっていることが確認できます。

    ```
    version https://git-lfs.github.com/spec/v1
    oid sha256:c0de104c1e68625629646025d15a6129a2b4b6496cd9ceacd7f7b5078e1849ba
    size 5242880
    ```

* LFS から Git に戻すには [こちら](https://stackoverflow.com/questions/35011366/move-git-lfs-tracked-files-under-regular-git/41961459#41961459) が参考になります。

    ```bash
    git lfs untrack '*.data'
    git rm --cached '*.data'
    git add '*.data'
    git commit -m "restore '*.data' to git from lfs"
    ```

* AWS CodePipeline ではどうやら GIT_LFS_SKIP_SMUDGE オプションが有効になっているためか、LFS からのファイル取得ができず、替わりにポインタファイルが降ってきます。
ビルドジョブとしては逆に都合がよいのですが、この挙動には注意が必要です。
