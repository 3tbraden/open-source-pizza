import { DependencyInfo, NpmRegistryResponse, packageObject } from "./type";
import axios from "axios";
import { Octokit } from "@octokit/rest";
import { GetResponseDataTypeFromEndpointMethod, OctokitResponse, RequestError } from "@octokit/types"


const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
});
type Content = OctokitResponse<GetResponseDataTypeFromEndpointMethod<typeof octokit.repos.getContent>, 200>
type ContentResponse = Promise<Content>

const get_repo_id_by_package_name = async (name: string): Promise<number> => {
  
  const repo_path = await axios.get(`https://registry.npmjs.org/${name}`).then(
    (res) => res.data
  ) as NpmRegistryResponse;

  const info = repo_path.repository.url.match(/https:\/\/github.com\/(.*?)\/(.*)/);

  const repo = await octokit.request("GET /repos/{owner}/{repo}", {
    owner: info![1],
    repo: (info![2].replace('.git', '')).split('/')[0]
  });

  return repo.data.id;
};

const get_file = async (id: number, file: string): Promise<ContentResponse> => {
  const repo = await octokit.request("GET /repositories/{id}", {
    id: id,
  });

  return await octokit.request("GET /repos/{owner}/{repo}/contents/{path}", {
    owner: repo.data.owner.login,
    repo: repo.data.name,
    path: file,
  });
};

export const getDependencies = async (id: number, etags: any): Promise<DependencyInfo> => {
  // check updates
  var updated = false;
  for (const id in etags) {
    const packages_file = await get_file(parseInt(id), "package.json");
    if (packages_file.headers.etag != etags[id]) {
      updated = true;
      break;
    }
  }

  if (!updated && Object.keys(etags).length != 0) {
    return {updated: false, ids: [], etags: etags}
  }

  const new_etags: object = {};
  const file = await get_file(id, 'package.json')
  etags[id] = file.headers.etag;
  const data = file.data;
  type keys = keyof typeof data;
  const package_obj = await axios.get(data['download_url' as keys], {
    method: "GET",
  }).then((res) => res.data) as packageObject;

  const list: number[] = [];

  if (package_obj.dependencies) {
    await getDependencyList(package_obj.dependencies, list, new_etags)
  }
  return {
    updated: true,
    ids: list,
    etags: new_etags
  };
};

export const getAccount = async (id: number): Promise<string> => {
  var file: Content;
  var account: string = "";
  try {
    file = await get_file(id, "account.txt");
    const data = file!.data;
    type keys = keyof typeof data;
    const content = await axios.get(
      data['download_url' as keys], { method: "GET" }
    ).then((res) => res.data);
    account = content.trim();
  } catch (err: any) {
    if (err.status === 404) {
      account = "";
    }
  } finally {
    return account;
  }
}

const getDependencyList = async (dependencies: object, list: number[], etags: any) => {
  if (!dependencies || Object.keys(dependencies).length == 0) {
    return list;
  }

  for (const dependency in dependencies) {
    const id = await get_repo_id_by_package_name(dependency);
    list.push(id);
    const file = await get_file(id, 'package.json');
    etags[id] = file.headers.etag;
    const data = file.data;
    type keys = keyof typeof data;
    const package_obj = await axios.get(data['download_url' as keys], {
      method: "GET",
    }).then((res) => res.data) as packageObject;
    await getDependencyList(package_obj.dependencies, list, etags);
  }
}

//getDependencies(516239052, {}).then((res) => console.log(res));
